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

require 'eventmachine'
require 'elasticbeanstalk/hostmanager/models/filepublication'
require 'elasticbeanstalk/hostmanager/tasks/task'
require 'elasticbeanstalk/hostmanager/utils'

module ElasticBeanstalk
  module HostManager
    module Tasks

      class SendFileToS3 < Task
        def run
          raise "Missing publication URL" unless @parameters['s3url']
          raise "Missing filename" unless @parameters['filename']          
          
          # If the file doesn't exist, log a message, set the publication state to error and return an error response
          unless ::File.exists?(@parameters['filename'])
            error_msg = "Cannot publish file #{@parameters['filename']}: file does not exist"
            logger.warn(error_msg)
            
            filepub = FilePublication.first(:filename => @parameters['filename'])
            filepub.update(:state => :error) unless filepub.nil?
            
            Event.store(class_name, error_msg, :warn, [ :s3 ], false)
            
            return generate_response(:error)
          end
          
          # Don't block, do the PUT later and store an event with results
          publish_op = proc {
            file = ::File.open(@parameters['filename'])
            
            begin
              logger.info("Publishing #{@parameters['filename']} to #{@parameters['s3url']}")
              
              filepub = FilePublication.first(:filename => @parameters['filename'], :state => :pending)

              if filepub.nil?
                logger.warn("File publication not found for filename #{@parameters['filename']}")
                return
              end

              filepub.update(:state => :in_progress)
              
              result = 
                ElasticBeanstalk::HostManager::Utils::S3Util.put(@parameters['s3url'], file, {'Content-Type' => @parameters['content-type']})
              
              msg = "Published #{file.path} in #{result[:time]} seconds"
              
              logger.info(msg)
              Event.store(class_name, msg, :info, [ :s3 ], false)
              filepub.update(:state => :complete)              
            rescue
              error_msg = "Failed to publish #{file.path} to #{@parameters['s3url']}: #{$!}"

              logger.warn(error_msg)
              Event.store(class_name, error_msg, :warn, [ :s3 ])
              filepub.update(:state => :error)
              
              # Never delete the file if there's an error, we may want to try it again
              filepub.delete = false
            ensure
              file.close
              
              if (filepub.delete)
                logger.info("Deleting file #{@parameters['filename']}")
                
                begin
                  ::File.delete(@parameters['filename'])
                rescue
                  logger.warn("Failed to delete #{@parameters['filename']}: #{$!}")
                end
              end
            end
          }
          
          # Kick off upload in its own thread since it blocks EM
          EM.defer(publish_op)

          generate_response(:deferred)
        end
      end # LogPub class
      
    end # Tasks module
  end
end
