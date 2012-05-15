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
require 'fileutils'
require 'elasticbeanstalk/hostmanager/operative/applicationhealthcheck'

module ElasticBeanstalk
  module HostManager
    class ELBHealthCheck
      @statedir = "#{ENV['HOME']}/var/state/healthcheck"         
      
      def self.check
        trigger_healthcheck_responders
        do_healthcheck
      end
      
      ## Fires any on-demand health check monitor triggers right now - calls 
      ## the customer application health check. These responders will 
      ## communicate by writing to the healthcheck state dir if needed
      def self.trigger_healthcheck_responders
        ## Application Healthcheck
        operative = ApplicationHealthcheck.new
        operative.check
      end
  
      ## Performs a healthcheck, checking...
      ##   * ...if $HOME/var/state/healthcheck is present and fails if not
      ##   * ...if $HOME/var/state/healthcheck is a directory and fails if not
      ##   * ...if  $HOME/var/state/healthcheck has any file inside
      ## If files are found in the healthcheck directory, they are opened and
      ##   their contents used for constructing a message
      ## If any of the above checks fail, an exception is raised with a message
      ##   detailing the error encountered 
      def self.do_healthcheck        
        if (not File.exists?(@statedir)) then
          FileUtils.mkdir(@statedir)
        end         
        
        if (not File.directory?(@statedir)) then
          raise "<internal>#{@statedir} is not a directory</internal>"
        end
        
        entries = Dir.entries(@statedir)                

        if (entries.length > 2)
          message = ""
          xml = Builder::XmlMarkup.new(:target => message, :indent => 2)
          
          xml.monitors { 
            entries.each do |entry|
              if (entry !~ /^\./)
                xml.operative(:name => entry) { |s|
                  s << IO.read(File.join(@statedir, entry))
                }
              end
            end
          }
          
          raise message
        else
          ElasticBeanstalk::HostManager::DeploymentManager.healthcheck_success
        end
      end
      
    end # ELBHealthCheck
  end # HostManager
end # ElasticBeanstalk
