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
          attr_reader :deploy_dir, :pre_deploy_script, :deploy_script, :post_deploy_script, :error_start_index, :config_dir
        end

        # Directories, etc
        @deploy_dir         = '/tmp/php-elasticbeanstalk-deployment'
        @config_dir         = '/tmp/php-elasticbeanstalk-deployment/application/beanstalk'
        @pre_deploy_script  = '/tmp/php_pre_deploy_app.sh'
        @deploy_script      = '/tmp/php_deploy_app.sh'
        @post_deploy_script = '/tmp/php_post_deploy_app.sh'

        # For error messages, get the last 512 chars of the deployment output
        @error_start_index = -512

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

        def pre_deploy
          application_version_url = @version_info.to_url

          deploy_script_contents = <<-END_PRE_DEPLOY_SCRIPT
#!/bin/bash
set -e

function logmsg() {
    echo $1
    /usr/bin/logger $1
}

logmsg "Beginning pre-deployment"
logmsg "Cleaning up deploy dir"
/usr/bin/sudo /bin/rm -rf #{CustomApplication.deploy_dir}
/bin/mkdir -p #{CustomApplication.deploy_dir}

logmsg "Downloading #{application_version_url}"
DOWNLOAD_TIME=`/usr/bin/time -f %e /usr/bin/wget -v --tries=10 --retry-connrefused -o #{CustomApplication.deploy_dir}/wget.log -O #{CustomApplication.deploy_dir}/application.zip "#{application_version_url}" 2>&1`
DOWNLOAD_RATE=`grep -o '(\\(.*\\/s\\))' #{CustomApplication.deploy_dir}/wget.log | sed 's/[\\(\\)]//g'`

logmsg "Checking application digest"
/usr/bin/openssl dgst -md5 #{CustomApplication.deploy_dir}/application.zip > #{CustomApplication.deploy_dir}/application_digest
/bin/echo 'MD5(#{CustomApplication.deploy_dir}/application.zip)= #{@version_info.digest}' > #{CustomApplication.deploy_dir}/expected_digest
/usr/bin/cmp #{CustomApplication.deploy_dir}/application_digest #{CustomApplication.deploy_dir}/expected_digest
logmsg "Digest matched"

echo "{\\"AppDownloadTime\\":\\"$DOWNLOAD_TIME\\",\\"AppDownloadRate\\":\\"$DOWNLOAD_RATE\\"}"
END_PRE_DEPLOY_SCRIPT

          HostManager.log "Starting PHP pre-deployment: Application version #{@version_info.version} from #{application_version_url}"

          begin
            ::File.open(CustomApplication.pre_deploy_script, 'w') { |f|
              f.write(deploy_script_contents)
            }

            ::File.chmod(0755, CustomApplication.pre_deploy_script)

            # Execute script, redirect stderr to stdout
            output = `#{CustomApplication.pre_deploy_script} 2>&1`

            # Raise an exception if script failed
            raise 'Application pre-deployment script failed' if ($?.exitstatus != 0)

            # Record deployment metrics from script
            metrics = JSON.parse(output.split("\n")[-1].chomp)

            # Convert download time from seconds to milliseconds and store metric
            unless (metrics['AppDownloadTime'].nil?)
              app_download_time = metrics['AppDownloadTime'].to_f * 1000

              HostManager.log "Application Download Time (ms): #{app_download_time}"

              HostManager.state.context[:metric].timings['AppDownloadTime'] =  app_download_time unless HostManager.state.context[:metric].nil?
            end

            # Rate could be Mb/s, Kb/s, etc, convert all to Kb/s
            unless (metrics['AppDownloadRate'].nil? || metrics['AppDownloadRate'][/[0-9]*/].nil?)
              app_download_rate = metrics['AppDownloadRate'][/[0-9]*/].to_f
              app_download_rate = app_download_rate * 1024 if metrics['AppDownloadRate'] =~ /MB/

              HostManager.log "Application Download Rate (kb/s): #{app_download_rate}"

              HostManager.state.context[:metric].counters['AppDownloadRate'] = app_download_rate unless HostManager.state.context[:metric].nil?
            end
          # Capture any Errno errors from the ::File operations
          rescue SystemCallError
            ex = ElasticBeanstalk::HostManager::DeployException.new('Failed to create application pre-deployment script')
            raise ex
          # All other exceptions, including the raised non-zero exit one go here
          rescue
            ex = ElasticBeanstalk::HostManager::DeployException.new("Failed application version #{@version_info.version} pre-deployment: #{$!}")
            ex.output = output[CustomApplication.error_start_index..-1] || output
            raise ex
          end
        end

        def deploy
          deploy_script_contents = <<-END_DEPLOY_SCRIPT
#!/bin/bash
set -e

function logmsg() {
    echo $1
    /usr/bin/logger $1
}

logmsg "Unzipping application"
/bin/mkdir -p #{CustomApplication.deploy_dir}/application
/bin/mkdir -p #{CustomApplication.deploy_dir}/backup

set +e
/usr/bin/unzip -o -qq #{CustomApplication.deploy_dir}/application.zip -d #{CustomApplication.deploy_dir}/application
if [ "$?" -ne 0 -a "$?" -ne 1 ]; then logmsg "Failed to unzip application"; exit 1; fi
set -e

/usr/bin/sudo chmod -R +x #{CustomApplication.config_dir}
logmsg "Running custom deploy script..."
/usr/bin/sudo #{CustomApplication.config_dir}/deploy.sh

logmsg "Deployment complete"
END_DEPLOY_SCRIPT

          HostManager.log "Starting deployment: Application version #{@version_info.version}"

          begin
            ::File.open(CustomApplication.deploy_script, 'w') { |f|
              f.write(deploy_script_contents)
            }

            ::File.chmod(0755, CustomApplication.deploy_script)

            # Execute script, redirect stderr to stdout
            output = `#{CustomApplication.deploy_script} 2>&1`

            # Raise an exception if script failed
            raise 'Application deployment script failed' if ($?.exitstatus != 0)

            HostManager.log 'Application successfully deployed'
          # Capture any Errno errors from the ::File operations
          rescue SystemCallError
            ex = ElasticBeanstalk::HostManager::DeployException.new('Failed to create application deployment script')
            raise ex
          # All other exceptions, including the raised non-zero exit one go here
          rescue
            ex = ElasticBeanstalk::HostManager::DeployException.new("Failed to deploy application version #{@version_info.version}: #{$!}")
            ex.output = output[CustomApplication.error_start_index..-1] || output
            raise ex
          end
        end

        def post_deploy
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
