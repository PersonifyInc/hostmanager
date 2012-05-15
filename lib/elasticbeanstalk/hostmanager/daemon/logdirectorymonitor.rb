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

require 'date'
require 'eventmachine'
require 'json'
require 'rb-inotify'
require 'timeout'
require 'elasticbeanstalk/hostmanager/daemon'
require 'elasticbeanstalk/hostmanager/log'
require 'elasticbeanstalk/hostmanager/models/event'

module ElasticBeanstalk
  module HostManager

    class LogDirectoryMonitor
      include Log
      include Daemon
      
      attr_accessor :log_directory
      attr_accessor :file_regex
      attr_accessor :notifier
      
      def initialize(log_directory, file_regex=nil)
        if (log_directory.nil? || !::File.exists?(log_directory) || !::File.directory?(log_directory))
          raise "#{log_directory} is not a valid log directory"
        end
        
        @log_directory = log_directory
        @file_regex = Regexp.new(file_regex) unless (file_regex.nil? || file_regex.empty?)
        
        # Inotify poller
        @notifier = INotify::Notifier.new

        # Watch for new files (aka rotated ones) in the configured
        # log directory
        @notifier.watch(@log_directory, :create, :move) do |inotify_event|

          # We need to register for these events, but we don't want to process them.
          if (inotify_event.flags.include?(:moved_from))
            next
          end

          filename = ::File.join(@log_directory, inotify_event.name)
          logger.info("Found candidate file in directory: #{filename}")

          already_rotated = false
          if (inotify_event.flags.include?(:moved_to))
            inotify_event.related.each do |related_event|
              related_filename = ::File.join(@log_directory, related_event.name)
              if (@file_regex.nil? || related_filename =~ @file_regex)
                logger.info("This file was moved from #{related_filename} which already matched pattern. Not rotating again.")
                already_rotated = true
                break
              end
            end
          end

          # If a filter regex was defined, check it
          if (!already_rotated && ::File.exists?(filename) && (@file_regex.nil? || filename =~ @file_regex))
            logger.info("Publishing new file in log directory '#{@log_directory}': #{filename}")
            # Queue up the file for publication, delete it when its done
            ElasticBeanstalk::HostManager::FilePublication.store(filename, true)
          end
        end
      end
      
      #
      #
      #
      def process_readable_event
        @notifier.process
      end

      #
      #
      #
      def run
        logger.info("Beginning to monitor log directory #{@log_directory}")
        
        EM.watch(@notifier.to_io, LogDirWatcher, self) { |c| 
          c.notify_readable = true 
        }
      end
      
      #
      #
      #
      def cleanup
        logger.info("Shutting down log dir monitor")
      end
      
      module LogDirWatcher
        def initialize(monitor)
          @monitor = monitor
        end
        
        def notify_readable
          @monitor.process_readable_event
        end
      end
    end # LogDirectoryMonitor class
    
  end # HostManager module
end # ElasticBeanstalk module
