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

require 'builder'
require 'erb'
require 'rack'
require 'sinatra/base'
require 'elasticbeanstalk/hostmanager/operative/elbhealthcheck'
require 'elasticbeanstalk/hostmanager/security'
require 'elasticbeanstalk/hostmanager/tasks'

module ElasticBeanstalk
  module HostManager
    class Server < Sinatra::Base
      @post_init_blocks = []
      
      def self.register_post_init_block(&blk)
        @post_init_blocks << blk unless blk.nil?
      end

      def self.post_init
        if (EM.reactor_running?)
          @post_init_blocks.each do |blk|
            blk.call
          end
        else
          HostManager.log "WARNING: Attempted to run post-init blocks, but EM reactor was not running"
        end
      end
      
      configure :development do
        Sinatra::Application.reset!
        use Rack::Reloader
      end

      # Don't generate fancy HTML for stack traces.
      disable :show_exceptions
      # Errors should be 5xx codes
      disable :raise_errors
      
      not_found do
        erb :index
      end

      ########################
      # Default context
      #
      get '/' do
        erb :index
      end
      
      ########################
      # ELB healthcheck
      #
      get '/healthcheck' do
        content_type 'application/xml', :charset => 'utf-8'
        
        builder do |xml|
          xml.instruct!
          
          begin
            ELBHealthCheck.check
            
            xml.healthcheck {
              xml.status('OK')
            }
          rescue => e
            status 500
            
            Event.store('healthcheck', "ELB healthcheck failed: #{e.message}", :critical, [ :healthcheck ])
            
            xml.healthcheck {
              xml.status('FAILED')
              xml.reason { xml << e.message }
            }
          end
        end
      end
            
      ########################
      # Tell the HM to do something
      #
      post '/tasks' do
        content_type 'application/json', :charset => 'utf-8'

        request = Tasks.parse_request(JSON.parse(params[:request]))

        results = {
          :api_versions => ElasticBeanstalk::HostManager.config.api_versions
        }

        if (request[:payload]['apiVersion'] && !ElasticBeanstalk::HostManager.config.api_versions.include?(request[:payload]['apiVersion']))
          results[:error] = 'Unsupported API version'
        else
          results.merge!(Tasks.execute(request[:payload]))
        end

        Tasks.generate_response(request[:iv], results)
      end
    end ## Server class
    
  end ## HostManager module
end ## ElasticBeanstalk module
