#############################################################################
# AWS ElasticBeanstalk Host Manager
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

require 'singleton'
require 'elasticbeanstalk/hostmanager/log'

module ElasticBeanstalk
  module HostManager

    class DaemonManager
      include Singleton
      include Log

      def initialize
        @daemons = []
      end
      
      def add(*daemons)
        @daemons = @daemons + daemons if !daemons.nil?
      end
      
      def start
        @daemons.each do |daemon|
          logger.info("Starting #{daemon.class.name}")
          daemon.start
        end
      end
      
      def stop
        @daemons.each do |daemon|
          logger.info("Stopping #{daemon.class.name}")
          daemon.stop
        end
      end
    end ## DaemonManager class

  end ## HostManager module
end ## ElasticBeanstalk module
