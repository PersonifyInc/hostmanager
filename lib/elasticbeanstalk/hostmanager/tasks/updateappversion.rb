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

require 'elasticbeanstalk/hostmanager/applications'
require 'elasticbeanstalk/hostmanager/tasks/task'

module ElasticBeanstalk
  module HostManager
    module Tasks
      
      class UpdateAppVersion < Task
        @@STATE_EXPIRATION_SECONDS = 1 * 60

        def run
          HostManager.log("Current Hostmanager State: #{HostManager.state.current}")
          HostManager.log("State Last Updated: #{HostManager.state.updated_at}")

          old_app_version = Version.last(:type => :application)
          # Parse but don't save yet.
          new_app_version_info = Version.parse_from_url(@parameters['versionUrl'], @parameters)

          HostManager.log("Old app version: #{old_app_version.version}")
          HostManager.log("New app version: #{new_app_version_info['s3version']}")

          if (old_app_version.version == new_app_version_info['s3version'])
            HostManager.log("New version is the same as the old version. Not deploying. Version: #{old_app_version.version}")
            return generate_response(old_app_version.to_info)
          elsif (HostManager.state.current == :ready || ((Time.now - @@STATE_EXPIRATION_SECONDS).to_datetime > HostManager.state.updated_at.to_datetime))
            if ((Time.now - @@STATE_EXPIRATION_SECONDS).to_datetime > HostManager.state.updated_at.to_datetime)
              HostManager.log("Allowing application deployment because of state timeout.")
            end
            HostManager.log("Deploying version: #{new_app_version_info['s3version']}")
            app_version = Version.from_url(:application, @parameters['versionUrl'], @parameters)
            ElasticBeanstalk::HostManager::DeploymentManager.deploy(ElasticBeanstalk::HostManager::Applications::PHPApplication.new(app_version))
            return generate_response(app_version.to_info)
          else
            raise "Hostmanager not in ready state."
          end
        end
      end

    end
  end
end
