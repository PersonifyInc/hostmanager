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

require 'elasticbeanstalk/hostmanager/applications'
require 'elasticbeanstalk/hostmanager/daemonmanager'
require 'elasticbeanstalk/hostmanager/daemon/logdirectorymonitor'
require 'elasticbeanstalk/hostmanager/deploymentmanager'
require 'elasticbeanstalk/hostmanager/models/event'
require 'elasticbeanstalk/hostmanager/models/filepublication'
require 'elasticbeanstalk/hostmanager/models/metric'
require 'elasticbeanstalk/hostmanager/models/version'
require 'elasticbeanstalk/hostmanager/utils/apacheutil'
require 'elasticbeanstalk/hostmanager/utils/bluepillutil'
require 'elasticbeanstalk/hostmanager/utils/ec2util'
require 'elasticbeanstalk/hostmanager/utils/phputil'

# Setup log dir monitor
ElasticBeanstalk::HostManager::DaemonManager.instance.add(ElasticBeanstalk::HostManager::LogDirectoryMonitor.new('/var/log/httpd', 'gz\Z'))
ElasticBeanstalk::HostManager::DaemonManager.instance.add(ElasticBeanstalk::HostManager::LogDirectoryMonitor.new('/var/log/ebapp', 'gz\Z'))

# Set the container type
ElasticBeanstalk::HostManager.config.container_type = :php

# Supported API versions
ElasticBeanstalk::HostManager.config.api_versions << '2011-08-29'

# After the Host Manager starts, but before the log monitoring daemons start,
# try to start Apache if it's not running.  Also, publish any timing metrics
# that were made available from the instance bootstrap.
ElasticBeanstalk::HostManager::Server.register_post_init_block {

  ElasticBeanstalk::HostManager::Applications::CustomApplication.ensure_configuration

  # Deploy app or just startup app server.
  application = ElasticBeanstalk::HostManager::Applications::CustomApplication.new(ElasticBeanstalk::HostManager.config.application_version)
  if ElasticBeanstalk::HostManager::DeploymentManager.should_deploy(application)
    application.mark_in_initialization
    ElasticBeanstalk::HostManager.log("Starting initial version deployment.")
    ElasticBeanstalk::HostManager::DeploymentManager.deploy(application)
  else
    ElasticBeanstalk::HostManager.log("Version already deployed. Starting Apache.")
    ElasticBeanstalk::HostManager::Utils::BluepillUtil.start_target("httpd")
  end

  # Start application servers
  begin
  	ElasticBeanstalk::HostManager::Applications::CustomApplication.start
  rescue Exception => e
  	ElasticBeanstalk::HostManager.log 'tried to start old app version'
  end
}
