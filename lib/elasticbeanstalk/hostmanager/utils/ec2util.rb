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

require 'base64'
require 'json'
require 'open-uri'
require 'elasticbeanstalk/hostmanager/config'

module ElasticBeanstalk
  module HostManager
    module Utils

      class EC2Util
        @@loopback_server = 'http://169.254.169.254'
        @@api_version     = 'latest'
        @@user_data_url = "#{@@loopback_server}/#{@@api_version}/user-data"
        @@meta_data_url = "#{@@loopback_server}/#{@@api_version}/meta-data"
        
        @@meta_data = [ :ami_id, :ami_launch_index, :ami_manifest_path, :ancestor_ami_ids, :block_device_mapping, :instance_id, :instance_type, :local_hostname, :local_ipv4, :kernel_id, :placement_availability_zone, :product_codes, :public_hostname, :public_ipv4, :public_keys, :ramdisk_id, :reservation_id, :security_groups ]

        def self.get_user_data
          user_data_contents = open(@@user_data_url).read
          user_data = {}
          
          # Try to JSON parse it, if that fails, try Base64 decoding it
          # and then JSON parsing it
          begin
            user_data = JSON.parse(user_data_contents)
          rescue
            user_data = JSON.parse(Base64.decode64(user_data_contents))
          end

          user_data
        end

        def self.get_meta_data(data_type)
          raise "Invalid meta-data: #{data_type}" unless @@meta_data.include?(data_type)
          data_url_part = data_type.to_s.sub(/placement_/, 'placement/').sub(/_/, '-')
          open("#{@@meta_data_url}/#{data_url_part}").read.strip
        end
      end

    end
  end
end
