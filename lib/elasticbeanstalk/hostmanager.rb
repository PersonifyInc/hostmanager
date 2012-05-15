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

require 'sinatra/base'
require 'elasticbeanstalk/hostmanager/config'
require 'elasticbeanstalk/hostmanager/daemon'
require 'elasticbeanstalk/hostmanager/daemonmanager'
require 'elasticbeanstalk/hostmanager/log'
require 'elasticbeanstalk/hostmanager/operative'
require 'elasticbeanstalk/hostmanager/server'

module ElasticBeanstalk
  module HostManager
    # Host Manager's config
    def self.config
      @config ||= ElasticBeanstalk::HostManager::Config.new
    end

    # Host Manager's state
    def self.state
      @state ||= ElasticBeanstalk::HostManager::State.new
    end
    
    # Simple log method for stdout
    def self.log(msg)
      puts "[#{Time.now}] #{msg}" unless msg.nil? || msg.empty?
    end

    def self.version
      @version ||= 'aws:elasticbeanstalk:hostmanager:20120113-1737'
    end
  end
end
