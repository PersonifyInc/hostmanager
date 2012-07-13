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

module ElasticBeanstalk
  module HostManager
    module Utils

      class BluepillUtil
        @bluepill_cmd    = '/usr/bin/sudo /opt/elasticbeanstalk/bin/bluepill'
        @bluepill_config = '/opt/elasticbeanstalk/srv/hostmanager/config/hostmanager.pill'

        def self.status
          Event.store('BluepillUtil', 'Checking Bluepill status', :info, [ :milestone, :apache ], false)
          HostManager.log 'Checking Bluepill status'
          `#{@bluepill_cmd} status`.chomp
        end

        def self.start_target(target)
          Event.store('BluepillUtil', 'Starting Bluepill target', :info, [ :milestone, :apache ], false)
          HostManager.log 'Starting Bluepill target'
          return if target.nil? || target.empty?
          `#{@bluepill_cmd} start #{target}`.chomp
        end

        def self.stop_target(target)
          Event.store('BluepillUtil', 'Stopping Bluepill target', :info, [ :milestone, :apache ], false)
          HostManager.log 'Stopping Bluepill target'
          return if target.nil? || target.empty?
          `#{@bluepill_cmd} stop #{target}`.chomp
        end

        def self.start
          # Log event for bluepill start
          Event.store('BluepillUtil', 'Starting Bluepill', :info, [ :milestone, :bluepill ], false)
          HostManager.log 'Starting Bluepill'
          `#{@bluepill_cmd} load #{@bluepill_config}`.chomp

          # Log event for bluepill startup completion
          Event.store('BluepillUtil', 'Bluepill startup complete', :info, [ :milestone, :bluepill ], false)
        end

        def self.quit
          Event.store('BluepillUtil', 'Quitting Bluepill', :info, [ :milestone, :bluepill ], false)
          HostManager.log 'Quitting Bluepill'
          `#{@bluepill_cmd} quit`.chomp
        end
      end

    end ## Utils module
  end ## HostManager module
end ## ElasticBeanstalk module
