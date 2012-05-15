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

require 'elasticbeanstalk/hostmanager/tasks/task'

module ElasticBeanstalk
  module HostManager
    module Tasks
      
      class SelfUpdate < Task
        class << self
          attr_reader :update_dir, :update_script
          attr_accessor :in_progress
        end

        @update_dir    = '/tmp/hostmanager_update'
        @update_script = '/tmp/self-update.sh'
        @in_progress   = false

        def install_hostmanager(url, digest)
          raise 'Missing Host Manager URL' unless url
          raise 'Missing Host Manager digest' unless digest

          if (SelfUpdate.in_progress)
            logger.warn('SelfUpdate already in progress')
            return
          end

          update_script_contents = <<-END_UPDATE_SCRIPT
#!/bin/bash
set -e
/bin/mkdir -p #{SelfUpdate.update_dir}
/usr/bin/wget -v --tries=10 --retry-connrefused -O #{SelfUpdate.update_dir}/hostmanager.tbz "#{url}"
/usr/bin/openssl dgst -md5 #{SelfUpdate.update_dir}/hostmanager.tbz > #{SelfUpdate.update_dir}/hostmanager_digest
/bin/echo 'MD5(#{SelfUpdate.update_dir}/hostmanager.tbz)= #{digest}' > #{SelfUpdate.update_dir}/expected_hostmanager_digest
/usr/bin/cmp #{SelfUpdate.update_dir}/hostmanager_digest #{SelfUpdate.update_dir}/expected_hostmanager_digest
/bin/rm #{SelfUpdate.update_dir}/*digest*
/bin/tar jxvf #{SelfUpdate.update_dir}/hostmanager.tbz -C /opt/elasticbeanstalk/srv
/bin/rm #{SelfUpdate.update_dir}/hostmanager.tbz
          END_UPDATE_SCRIPT

          ::File.open(SelfUpdate.update_script, 'w') { |f|
            f.write(update_script_contents)
          }

          ::File.chmod(0755, SelfUpdate.update_script)

          # Unpack tarball and restart bluepill
          EM.system(SelfUpdate.update_script) { |output, status|
            if (status.exitstatus == 0)
              logger.info("Self-update complete: #{output}")
              Event.store(class_name, 'Self-update completed', :info, [ :hostmanager, :update ])

              # Force the process to shutdown so Bluepill will start it up
              # again
              Kernel::exit
            else
              logger.error("Self-update failed: #{output}")
              Event.store(class_name, 'Self-update failed with exit status: #{status.exitstatus}', :warn, [ :hostmanager, :update ])
              SelfUpdate.in_progress = false
            end
          }
        end

        def run
          hostmanager_url    = @parameters['hostManagerUrl']
          hostmanager_digest = @parameters['digest']

          install_hostmanager(hostmanager_url, hostmanager_digest)

          generate_response(:deferred)
        end
      end # SystemUpdate class
      
    end # Tasks module
  end # HostManager module
end # ElasticBeanstalk module
