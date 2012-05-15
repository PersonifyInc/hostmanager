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
require 'dm-core'
require 'dm-types'

module ElasticBeanstalk
  module HostManager
    
    class Event
      include DataMapper::Resource
      
      property :id,        Serial
      property :timestamp, DateTime
      property :source,    String
      property :message,   String
      property :severity,  String
      property :tags,      Json
      property :customer_visible, Boolean

      def self.store(source, message, severity, tags, customer_visible=true)
        return if source.nil? || source.empty? || message.nil? || message.empty?
        
        severity = :debug if severity.nil?
        tags = [] if tags.nil?

        event = new(:timestamp => DateTime.now, :source => source, :message => message, :severity => severity, :tags => tags, :customer_visible => customer_visible)
        event.save
      end      
    end # Event class
    
  end # HostManager module
end # ElasticBeanstalk module
