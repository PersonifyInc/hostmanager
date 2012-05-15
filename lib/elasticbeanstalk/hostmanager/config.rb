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

#
# In-memory configuration class, parses and stores settings from the AWS 
# Elastic Beanstalk Service JSON config file
#
require 'date'
require 'digest/md5'
require 'ostruct'
require 'json'

module ElasticBeanstalk
  module HostManager

    class Config
      attr_accessor :container_type
      attr_reader   :api_versions
      attr_reader   :instance_type
      
      @@cipher_type = 'aes-256-cbc'

      def initialize
        @config = OpenStruct.new(defaults)
        @container_type = :unknown
        @api_versions = []
        @instance_type = ElasticBeanstalk::HostManager::Utils::EC2Util.get_meta_data(:instance_type)
        
        sync_config
      end
      
      def application
        @config.application
      end
        
      def elasticbeanstalk
        @config.elasticbeanstalk
      end
      
      def container
        @config.container
      end
      
      def application_version
        Version.last(:type => :application)
      end

      def version
        Version.last(:type => :configuration) || parse_user_data
      end
            
      # Download the encrypted config from S3
      def sync_config(config_ver=version)
        config_url = config_ver.to_url

        encrypted_config_result = 
          ElasticBeanstalk::HostManager::Utils::S3Util.get(config_url)

        raise "Error downloading encrypted config version (#{config_url}): empty result" if encrypted_config_result.nil? || 
                                                                                            encrypted_config_result[:response].nil? || 
                                                                                            encrypted_config_result[:response].body.nil?
        
        decrypted_config = 
          ElasticBeanstalk::HostManager::AES.decrypt(Base64::decode64(encrypted_config_result[:response].body),
                                             Base64::decode64(config_ver.cipher_key),
                                             Base64::decode64(config_ver.cipher_iv),
                                             @@cipher_type)

        parse_options(JSON.parse(decrypted_config))  

        latest_app = application_version
        latest_app_version = latest_app.nil? ? '' : latest_app.version

        Version.store(:application, @config.elasticbeanstalk['Application']) if (@config.elasticbeanstalk['Application']['s3key'] &&
                                                                         @config.elasticbeanstalk['Application']['s3version'] &&
                                                                         @config.elasticbeanstalk['Application']['s3version'] != latest_app_version &&
                                                                         @config.elasticbeanstalk['Application']['queryParams'] &&
                                                                         @config.elasticbeanstalk['Application']['s3bucket'] &&
                                                                         @config.elasticbeanstalk['Application']['digest'])

        config_ver.update(:deployed => true)
      end

      private
      
      def defaults
        @defaults ||= {
          :application => {},
          :elasticbeanstalk => {
            'Application' => {
              'Application Healthcheck URL'  => '/',
              'Application Log Storage'      => 'lincoln'
            }
          },
          :container => {},
          :location => {}
        }
      end

      def parse_user_data
        user_data = ElasticBeanstalk::HostManager::Utils::EC2Util.get_user_data

        raise 'Missing configuration version info in user data' unless user_data['configuration']

        Version.store(:configuration, user_data['configuration'])
      end

      def parse_options(config_options={})
        config_options.each do |main_section, sub_section|
          case main_section.downcase
          when 'application' then
            @config.application.merge!(sub_section)
          when 'elasticbeanstalk' then
            @config.elasticbeanstalk.merge!(sub_section)
          when 'container' then
            @config.container.merge!(sub_section)
          end
        end
      end

      # Strips spaces and converts camel case strs to lowercase w/ underscores,
      # returns a symbol based on the str
      # 'Foo Bar' => :foo_bar, 'FooBar' => :foo_bar
      def to_symbol(str)
        str.gsub(/ /, '').gsub(/\B[A-Z]+/, '_\&').downcase.to_sym
      end
    end ## Config class
    
  end ## HostManager module
end ## ElasticBeanstalk module
