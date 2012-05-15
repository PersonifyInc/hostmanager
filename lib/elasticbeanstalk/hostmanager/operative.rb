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

require 'fileutils'
require 'elasticbeanstalk/hostmanager/log'

module ElasticBeanstalk
  module HostManager

    class Operative
      include Log
      
      def class_name
        self.class.name.split('::').last
      end
      
      def stale? (ps_info)
        return false
      end
    end ## Operative class
    
    module OpFileUtils
      def self.ensure_directory_exists (dir)
        if (! File.exists?(dir))
          FileUtils.makedirs(dir)
        end
      end

      def self.write (path, msg, mode="a", perms=0640)
        dir = File.dirname(path)
        ensure_directory_exists(dir)
        File.open(path, mode, perms) { |f| f << msg}
      end 

      def self.touch (path)
        dir = File.dirname(path)
        ensure_directory_exists(dir)
        FileUtils.touch(path)
      end
    end ## OpFileUtils module
    
    module HealthCheck
      HEATH_CHECK_DIR = ::File.join(ENV['HOME'], 'var', 'state', 'healthcheck')
      
      def self.write (check_file, msg, mode="w", perms=0640)
        path = File.join(HEATH_CHECK_DIR, check_file)
        OpFileUtils.write(path, msg, mode, perms)
      end
      
      def self.touch (check_file)
        path = File.join(HEATH_CHECK_DIR, check_file)
        OpFileUtils.touch(path)
      end
      
      def self.remove (check_file)
        path = File.join(HEATH_CHECK_DIR, check_file)
        if (File.exists?(path))
          FileUtils.rm(path)
        end
      end
    end ## HealthCheck module

  end ## HostManager module
end ## ElasticBeanstalk module
