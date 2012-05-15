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

require 'elasticbeanstalk/hostmanager/operative'
require 'net/http'
require 'uri'

module ElasticBeanstalk
  module HostManager 
  
    class ApplicationHealthcheck < Operative
      class << self
        attr_reader :user_agent, :read_timeout
      end

      # User Agent
      @user_agent = 'AWS Elastic Beanstalk Host Manager - Health Check'

      # Timeout healthcheck after 3 seconds
      @read_timeout = 3

      def initialize
        super
      end
    
      ## Creates the healthcheck URL from config settings
      def healthcheck_url
        "http://localhost#{HostManager.config.elasticbeanstalk['Application']['Application Healthcheck URL']}"
      end
    
      ## Performs HTTP GET on a URL
      def fetch(uri_str, limit = 10)
        raise 'HTTP redirect too deep' if limit == 0
      
        # TODO: Switch to EventMachine HTTP client
        uri = URI.parse(uri_str)
        http = Net::HTTP.new(uri.host || 'localhost' , uri.port || 80)
        http.read_timeout = ApplicationHealthcheck.read_timeout

        headers = {
          'User-Agent' => ApplicationHealthcheck.user_agent
        }

        path = uri.path.start_with?('/') ? uri.path : "/#{uri.path}"
        response = http.get2(path, headers)
        
        case response
          when Net::HTTPSuccess     then response
          when Net::HTTPRedirection then fetch(response['location'], limit - 1)
        else
          response
        end
      end
      
      ## Performs an HTTP GET on the healthcheck URL, stores
      ## file with error message if unsuccessful
      def perform_application_healthcheck 
	 success = false
         err_msg = nil
      
        begin
          response = fetch(healthcheck_url)
          if (response.is_a?(Net::HTTPSuccess))
            success = true
          else
            success = false
            err_msg = "Received HTTP Response Code: #{response.code}"
          end
        rescue => e
          success = false
          err_msg = e.message        
        end
      
        if success
          HealthCheck.remove(self.class_name)
        else
          HealthCheck.write(self.class_name, err_msg)
        end
      end

      ## Perform the application healthcheck
      def check
        perform_application_healthcheck
      end
    end # ApplicationHealthcheck class
    
  end # HostManager module
end  # ElasticBeanstalk module
