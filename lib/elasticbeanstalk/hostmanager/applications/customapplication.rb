#############################################################################
# AWS Elastic Beanstalk Host Manager
# Copyright 2011 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the “License”). You may
# not use this file except in compliance with the License. A copy of the
# License is located at
#
# http://aws.amazon.com/asl/
#
# or in the “license” file accompanying this file. This file is
# distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, express or implied. See the License for the specific
# language governing permissions and limitations under the License.
#

require 'json'

module ElasticBeanstalk
  module HostManager
    module Applications

      class CustomApplication < Application
        class << self
          attr_reader :is_initialization_phase, :deploy_dir, :pre_deploy_script, :deploy_script, :post_deploy_script, :error_start_index, :config_dir
        end

        # Directories, etc
        @deploy_dir         = '/tmp/php-elasticbeanstalk-deployment'
        @config_dir         = '/tmp/php-elasticbeanstalk-deployment/application/beanstalk'
        @pre_deploy_script  = '/tmp/php_pre_deploy_app.sh'
        @deploy_script      = '/tmp/php_deploy_app.sh'
        @post_deploy_script = '/tmp/php_post_deploy_app.sh'

        # For error messages, get the last 512 chars of the deployment output
        @error_start_index = -512

        @is_initialization_phase = false

        # Run app server shutdown script
        def self.stop
        	HostManager.log "Stopping application servers..."
        	# Execute script, redirect stderr to stdout
            output = `#{CustomApplication.config_dir}/shutdown.sh`

			if ($?.exitstatus != 0 || output =~ /FAILED/)
				HostManager.log 'Application servers failed to stop'
				Event.store(:apache, 'Application servers failed to stop', :critical, [ :apache ])
			else
				HostManager.log 'Application servers stopped'
				Event.store(:apache, 'Application servers stopped', :info, [ :apache ], true)
			end
        end

        def self.restart
        	stop
        	start
        end

        # Update custom config from environment vars
        def self.update_config(config_vars)
        	HostManager.log 'update app config'
        	var_string = config_vars.map{|e| e.join('=')}.join(' ')
        	if ::File.exists?("#{CustomApplication.config_dir}/config.sh")
        		output = `/usr/bin/sudo #{CustomApplication.config_dir}/config.sh #{var_string}`
        		HostManager.log output
        	end
		end

        def self.ensure_configuration
          HostManager.log 'Writing environment config'
          ElasticBeanstalk::HostManager::Utils::PHPUtil.write_sdk_config(ElasticBeanstalk::HostManager.config.application['Environment Properties'])

          HostManager.log 'Updating php.ini options'
          ElasticBeanstalk::HostManager::Utils::PHPUtil.update_php_ini(ElasticBeanstalk::HostManager.config.container['Php.ini Settings'])

          HostManager.log 'Updating Apache options'
          ElasticBeanstalk::HostManager::Utils::ApacheUtil.update_httpd_conf(ElasticBeanstalk::HostManager.config.container['Php.ini Settings'])
        	
          HostManager.log 'Update custom application config'
 	 	  update_config(ElasticBeanstalk::HostManager.config.application['Environment Properties'])
        end

        def mark_in_initialization
          @is_initialization_phase = true
        end

        # Run app server startup script
        def self.start
        	HostManager.log "Starting application servers..."
        	# Execute script, redirect stderr to stdout
            output = `#{CustomApplication.config_dir}/startup.sh`

			if ($?.exitstatus != 0 || output =~ /FAILED/)
				HostManager.log 'Application servers failed to start'
				Event.store(:apache, 'Application servers failed to start', :critical, [ :apache ])
			else
				# Log event for Apache startup completion
				HostManager.log 'Application servers started'
				Event.store(:apache, 'Application servers startup complete', :info, [ :milestone, :apache ], true)
			end
        end

        def pre_deploy
          HostManager.log "Starting pre-deployment."

          application_version_url = @version_info.to_url

          HostManager.log "Re-building the Deployment Directory"
          output = `/usr/bin/sudo /bin/rm -rf #{CustomApplication.deploy_dir}`
          HostManager.log "Output: #{output}"
          output = `/usr/bin/sudo /bin/mkdir -p #{CustomApplication.deploy_dir} 2>&1`
          HostManager.log "Output: #{output}"
          raise "Unable to create #{CustomApplication.deploy_dir}" unless File.directory?(CustomApplication.deploy_dir)

          HostManager.log "Changing owner, groups and permissions for the deployment directory."
          output = `/usr/bin/sudo /bin/chown elasticbeanstalk:elasticbeanstalk #{CustomApplication.deploy_dir}`
          HostManager.log "Output: #{output}"
          output = `/usr/bin/sudo /bin/chmod -Rf 0777 #{CustomApplication.deploy_dir}`
          HostManager.log "Output: #{output}"

          HostManager.log "Downloading / Validating Application version #{@version_info.version} from #{application_version_url}"
          output = `/usr/bin/time -f %e /usr/bin/wget -v --tries=10 --retry-connrefused -o #{CustomApplication.deploy_dir}/wget.log -O #{CustomApplication.deploy_dir}/application.zip "#{application_version_url}" 2>&1`
          HostManager.log "Output: #{output}"
          raise "Application download from #{application_version_url} failed" unless File.exists?("#{CustomApplication.deploy_dir}/application.zip")

          output = output.to_f * 1000
          HostManager.log "Application Download Time (ms): #{output}"
          HostManager.state.context[:metric].timings['AppDownloadTime'] = output unless HostManager.state.context[:metric].nil?

          output = `grep -o '(\\(.*\\/s\\))' #{CustomApplication.deploy_dir}/wget.log | sed 's/[\\(\\)]//g' 2>&1` if File.exists?("#{CustomApplication.deploy_dir}/wget.log")
          if output =~ /([0-9]+(?:\.[0-9]*))\s+(KB|MB|GB).*/
            output = $~[1].to_f
            output *= 1024 if $~[2] == 'MB' || $~[2] == 'GB'
            output *= 1024 if $~[2] == 'GB'
            output = output.to_i
            HostManager.log "Application Download Rate (kb/s): #{output}"
            HostManager.state.context[:metric].counters['AppDownloadRate'] = output unless HostManager.state.context[:metric].nil?
          elsif
            HostManager.log "Application Download Rate could not be determined: #{output}"
          end

          output = `/usr/bin/openssl dgst -md5 #{CustomApplication.deploy_dir}/application.zip 2>&1`
          output = $~[1] if output =~ /MD5\([^\)]+\)= (.*)/
          HostManager.log "Output: #{output}"
          raise "Application digest (#{output}) does not match expected digest (#{@version_info.digest})" unless output == @version_info.digest

        rescue
          HostManager.log("Version #{@version_info.version} PRE-DEPLOYMENT FAILED: #{$!}\n#{$@.join('\n')}")
          ex = ElasticBeanstalk::HostManager::DeployException.new("Version #{@version_info.version} pre-deployment failed: #{$!}")
          ex.output = output || ''
          raise ex
        end

        def deploy
          HostManager.log "Starting deployment."

          HostManager.log "Changing owner, groups and permissions for the deployment directory."
          output = `/usr/bin/sudo /bin/chown elasticbeanstalk:elasticbeanstalk #{CustomApplication.deploy_dir}`
          HostManager.log "Output: #{output}"
          output = `/usr/bin/sudo /bin/chmod -Rf 0777 #{CustomApplication.deploy_dir}`
          HostManager.log "Output: #{output}"

          HostManager.log "Creating #{CustomApplication.deploy_dir}/application and #{CustomApplication.deploy_dir}/backup"
          output = `/bin/mkdir -p #{CustomApplication.deploy_dir}/application 2>&1`
          HostManager.log "Output: #{output}"
          raise "Unable to create #{CustomApplication.deploy_dir}/application" if $?.exitstatus != 0
          
          output = `/bin/mkdir -p #{CustomApplication.deploy_dir}/backup 2>&1`
          HostManager.log "Output: #{output}"
          raise "Unable to create #{CustomApplication.deploy_dir}/backup" if $?.exitstatus != 0

		  HostManager.log "Unzipping #{CustomApplication.deploy_dir}/application.zip to #{CustomApplication.deploy_dir}/application"
          output = `/usr/bin/unzip -o #{CustomApplication.deploy_dir}/application.zip -d #{CustomApplication.deploy_dir}/application 2>&1`
          HostManager.log "Output: #{output}"
          raise "Failed to unzip #{CustomApplication.deploy_dir}/application.zip" if $?.exitstatus != 0

          HostManager.log "Making custom config files executable"
          output = `/usr/bin/sudo /bin/chmod -R +x #{CustomApplication.config_dir} 2>&1`
          HostManager.log "Output: #{output}"
          raise "Unable to set mode of #{CustomApplication.web_root_dir}" if $?.exitstatus != 0
          
          HostManager.log "Running custom deployment script"
          output = `/usr/bin/sudo #{CustomApplication.config_dir}/deploy.sh 2>&1`
          HostManager.log "Output: #{output}"
          raise "Custom deployment script failed." if $?.exitstatus != 0

          ElasticBeanstalk::HostManager::Utils::BluepillUtil.start_target("httpd") if @is_initialization_phase

        rescue
          HostManager.log("Version #{@version_info.version} DEPLOYMENT FAILED: #{$!}\n#{$@.join('\n')}")
          ex = ElasticBeanstalk::HostManager::DeployException.new("Version #{@version_info.version} deployment failed: #{$!}")
          ex.output = output || ''
          raise ex
        end

        def post_deploy
        	HostManager.log "Starting post-deployment."
			# Update app config (in case the config scripts changed)
			HostManager.log 'Post Deloy: Update app config'
			CustomApplication.update_config(ElasticBeanstalk::HostManager.config.application['Environment Properties'])
			CustomApplication.restart
			# Restart Apache
			logger.info('Restarting Apache')
			ElasticBeanstalk::HostManager::Utils::ApacheUtil.restart
        end

      end # CustomApplication class

    end
  end
end
