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

module ElasticBeanstalk
  module HostManager
    
    class FilePublication
      include DataMapper::Resource
      
      property :id,        Serial
      property :timestamp, DateTime
      property :filename,  String
      property :state,     String
      property :delete,    Boolean, :default => false
      
      def self.store(filename, delete, timestamp=DateTime.now)
        return if filename.nil? || !::File.exists?(filename)
        
        if (first(:filename => filename).nil?)
          filepub = new(:filename => filename, :delete => delete, :timestamp => timestamp, :state => :pending)
          filepub.save
        else
          puts "Attempted to publish file '#{filename}' that already has been flagged for publication"
        end
      end
    end # FilePublication class
    
  end # HostManager module
end # ElasticBeanstalk module
