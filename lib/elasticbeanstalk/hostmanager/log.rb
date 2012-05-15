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

require 'logger'

module ElasticBeanstalk
  module HostManager
    module Log
      LOG_DIR = "#{ENV['HOME']}/var/log"
      
      def logger
        if @logger.nil?
          # Each class gets a log that rotates daily
          @logger = Logger.new("#{LOG_DIR}/#{self.class.name.split('::').last}.log", 'daily')
          
          # Change default level to INFO
          @logger.level = Logger::INFO
          
          # Change format
          @logger.datetime_format = "%Y-%m-%d %H:%M:%S "
        end
        
        @logger
      end
      
      def class_name
        self.class.name.split('::').last
      end
    end
  end
end
