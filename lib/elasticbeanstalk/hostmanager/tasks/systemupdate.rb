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
      
      class SystemUpdate < Task
        def run
          EM.system('/usr/bin/sudo /usr/bin/yum -y update') { |output, status|
            if (status.exitstatus == 0)
              logger.info("Yum update complete: #{output}")
              Event.store(class_name, 'System update succeeded', :info, [ :system, :update ])
            else
              logger.error("Yum update failed: #{output}")
              Event.store(class_name, 'System update failed', :warn, [ :system, :update ])
            end
          }

          generate_response(:deferred)
        end
      end # SystemUpdate class
      
    end # Tasks module
  end # HostManager module
end # ElasticBeanstalk module
