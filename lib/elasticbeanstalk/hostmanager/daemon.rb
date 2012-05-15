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

module ElasticBeanstalk
  module HostManager
    
    module Daemon
      # Main loop/tasks to run in thread
      def run
      end
      
      # Use this method to close any handles, etc
      def cleanup
      end
      
      def start 
        # Tells Thin's EventMachine reactor loop to start
        # your daemon on startup
        #
        # WARNING: Do NOT have your daemon code block, 
        # use EventMachine APIs if you have to do any 
        # operations around system calls, async requests, etc
        EM.next_tick { self.run }
      end
      
      def stop
        # Cleanup anything that needs it
        self.cleanup
      end
    end ## Daemon module
    
  end ## HostManager module
end ## ElasticBeanstalk module
