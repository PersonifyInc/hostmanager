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

require 'open-uri'
require 'openssl'
require 'elasticbeanstalk/hostmanager/utils/ec2util'

module ElasticBeanstalk
  module HostManager
    class Key
      
      def self.generate(timestamp, material=nil)
        if material.nil?
          material = 
            ElasticBeanstalk::HostManager::Utils::EC2Util.get_meta_data(:instance_id) + 
            ElasticBeanstalk::HostManager::Utils::EC2Util.get_meta_data(:reservation_id)
        end

        Digest::SHA256.digest(material + timestamp)
      end
    end # Key class
  end # HostManager module
end # ElasticBeanstalk module
