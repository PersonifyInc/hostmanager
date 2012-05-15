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
require 'uri'

module ElasticBeanstalk
  module HostManager
    
    class Version
      include DataMapper::Resource
      
      property :id,           Serial
      property :type,         String
      property :s3bucket,     String
      property :s3key,        String
      property :version,      String
      property :query_params, String
      property :digest,       String
      property :cipher_key,   String
      property :cipher_iv,    String
      property :error,        String
      property :timestamp,    Time
      property :deployed,     Boolean
      
      def self.store(type, version_info)
        return if version_info.nil?

        # Find the previous version of this type
        previous_version = last(:type => type)

        # If this version already exists, just return it
        return previous_version unless previous_version.nil? || previous_version.version != version_info['s3version']

        # Create and save the new version
        version = new

        version.type         = type
        version.s3bucket     = version_info['s3bucket'] || previous_version.s3bucket
        version.s3key        = version_info['s3key'] || previous_version.s3key
        version.version      = version_info['s3version']
        version.query_params = version_info['queryParams']
        version.digest       = version_info['digest']
        version.cipher_key   = version_info['key']
        version.cipher_iv    = version_info['iv']
        version.deployed     = false
        version.timestamp    = Time.now.utc

        version.save
        version
      end

      def self.parse_from_url(url, extra_params={})
        # Split url into:
        # scheme, userinfo, host, port, registry, path, opaque, query, fragment
        url_parts = URI.split(url)

        version_info = {
          's3bucket'    => url_parts[2].slice(/(.*).s3.amazonaws.com/, 1),
          's3key'       => url_parts[5].slice(1..-1),
          's3version'   => url_parts[7].slice(/versionId=([^&]*)/, 1),
          'queryParams' => url_parts[7],
          'digest'      => extra_params['digest'],
          'key'         => extra_params['key'],
          'iv'          => extra_params['iv']
        }
      end

      def self.from_url(type, url, extra_params={})
        return if url.nil?

        version_info = parse_from_url(url, extra_params)
        store(type, version_info)
      end

      def to_url
        "https://#{@s3bucket}.s3.amazonaws.com/#{@s3key}?#{@query_params}"
      end

      # Returns a Hash with the version info AWSEB is
      # expecting for various calls
      def to_info
        {
          :version   => version,
          :digest    => digest,
          :deployed  => deployed,
          :timestamp => timestamp.to_i * 1000,
          :error     => error
        }
      end
    end # Version class
    
  end # HostManager module
end # ElasticBeanstalk module
