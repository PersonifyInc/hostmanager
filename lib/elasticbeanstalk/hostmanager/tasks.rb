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

require 'digest/md5'
require 'json'
require 'time'
require 'elasticbeanstalk/hostmanager/tasks/task'

Dir[::File.join(::File.dirname(__FILE__), 'tasks', '*rb')].uniq.each do |task_file|
  require task_file
end

module ElasticBeanstalk
  module HostManager
    module Tasks
      @@cipher_type = 'aes-256-cbc'
      @@timestamp_window = 1800
      
      def self.parse_request(request)
        timestamp = request['timestamp']
        validate_timestamp(timestamp)
        
        iv        = Base64::decode64(request['iv'])
        payload   = Base64::decode64(request['payload'])
        
        {
          :timestamp => timestamp,
          :iv => iv,
          :payload => JSON.parse(AES.decrypt(payload, 
                                             Key.generate(timestamp),
                                             iv,
                                             @@cipher_type))
        }
      end
     
      def self.validate_timestamp(timestamp) 
        raise "Provided timestamp is not valid." unless (Time.now - Time.iso8601(timestamp)).abs < @@timestamp_window
      end
 
      def self.execute(task)
        create(task['name'], task['parameters'] || {}).run
      end
      
      def self.generate_response(iv, result={})
        timestamp = generate_timestamp
        
        payload = 
          AES.encrypt(result.to_json, 
                      Key.generate(timestamp),
                      iv,
                      @@cipher_type)

        {
          :timestamp => timestamp,
          :iv => Base64::encode64(iv).strip,
          :payload => Base64::encode64(payload).strip
        }.to_json
      end
      
      private

      def self.lookup(task_module, target)
        result = task_module.const_get(target)
        raise "Unable to find #{target} in module #{task_module}" if result.to_s[task_module.to_s+"::"].nil?
        result
      end

      def self.create(task_name, params={})
        lookup(ElasticBeanstalk::HostManager::Tasks, task_name).new(params)
      end
      
      def self.generate_timestamp
        Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')
      end
    end # Tasks module
  end # HostManager module
end # ElasticBeanstalk module
