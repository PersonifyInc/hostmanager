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
    
      class SystemUtil
        # Execute a system command, wrapper around EM.system.  Takes a command and
        # a block to process the output
        def self.execute(cmd, &blk)
          EM.system(cmd, &blk)
        end
        
        def self.kernel_version
          `uname -sr`.chomp
        end

        def self.process_list
          `ps auxwww`.chomp.split("\n")[1..-1]
        end

        def self.memory_info
          meminfo = `free | grep -A 1 buffers/cache | awk '{print \$3, \$4}'`.chomp.split(' ')
          
          {
            :mem_used  => "#{meminfo[0].to_i / 1024}M",
            :mem_free  => "#{meminfo[1].to_i / 1024}M",
            :swap_used => "#{meminfo[2].to_i / 1024}M",
            :swap_free => "#{meminfo[3].to_i / 1024}M"
          }
        end

        def self.uptime
          uptime = `uptime`.chomp

          {
            :uptime   => uptime[/up (.*?),/, 1],
            :load_avg => uptime[/load average: (.*?)$/, 1]
          }
        end
      end ## SystemUtil class
      
    end ## Utils module
  end ## HostManager module
end ## ElasticBeanstalk module
