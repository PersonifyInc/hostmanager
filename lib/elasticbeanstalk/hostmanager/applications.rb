# -*- coding: utf-8 -*-
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

module ElasticBeanstalk
  module HostManager
    module Applications

      # Base class for an application the Host Manager is capable
      # of deploying
      class Application
        attr_reader :version_info

        def initialize(app_version)
          @version_info = app_version
        end

        # Pre-deployment hooks
        def pre_deploy; end

        # Deploy the app, up to subclass to implement
        def deploy; end

        # Post-deployment hooks
        def post_deploy; end
      end

    end
  end
end

Dir[::File.join(::File.dirname(__FILE__), 'applications', '*rb')].uniq.each do |app_file|
  require app_file
end
