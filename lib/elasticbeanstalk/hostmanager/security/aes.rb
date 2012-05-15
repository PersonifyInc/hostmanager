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

require 'openssl'

module ElasticBeanstalk
  module HostManager
    module AES
      def self.decrypt(data, key, iv, cipher_type)
        aes = OpenSSL::Cipher::Cipher.new(cipher_type)
        aes.decrypt
        aes.key = key
        aes.iv  = iv if !iv.nil?
        aes.update(data) + aes.final
      end
      
      def self.encrypt(data, key, iv, cipher_type)
        aes = OpenSSL::Cipher::Cipher.new(cipher_type)
        aes.encrypt
        aes.key = key
        aes.iv  = iv if !iv.nil?
        aes.update(data) + aes.final
      end
    end # AES module
  end # HostManager module
end # ElasticBeanstalk module
