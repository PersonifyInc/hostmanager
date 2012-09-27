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

require 'fileutils'

module ElasticBeanstalk
  module HostManager
    module Utils

      class PHPUtil
        # php.ini files
        @php_ini_file = '/etc/php.d/custom.ini'
        @env_ini_file = '/etc/php.d/environment.ini'

        def self.update_php_ini(php_options)
          Event.store(:php, 'Updating custom.ini', :info, [ :milestone, :php ], false)
          return if php_options.nil?

          new_options_section = []

          php_options.each do |key, val|
            if key != 'document_root'
              new_options_section << "#{key} = #{val}"
            end
          end

          tmp_file = ::File.new(@php_ini_file, 'w+')
          tmp_file << "\n"
          tmp_file << new_options_section.join("\n")
          tmp_file << "\n"
          tmp_file.close
        end

        def self.write_sdk_config(env_props)
          Event.store(:php, 'Updating environment.ini', :info, [ :milestone, :php ], false)
          return if env_props.nil?

          # log the values
          ElasticBeanstalk::HostManager.log env_props

          new_options_section = []

          env_props.each do |key, val|
            if key == 'AWS_ACCESS_KEY_ID'
              new_options_section << "aws.access_key = \"#{val}\""
            elsif key == 'AWS_SECRET_KEY'
              new_options_section << "aws.secret_key = \"#{val}\""
            else
              new_options_section << "aws.#{key.downcase} = \"#{val}\""
            end
          end

          tmp_file = ::File.new(@env_ini_file, 'w+')
          tmp_file << "\n"
          tmp_file << new_options_section.join("\n")
          tmp_file << "\n"
          tmp_file.close
        end
      end
    end
  end
end
