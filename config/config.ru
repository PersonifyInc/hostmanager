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
# Host Manager rackup file
#

# Path to the SQLite DB
DATABASE_PATH = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', 'db'))

# Add the Host Manager source to the lib path
HOSTMANAGER_LIB_PATH = ::File.expand_path(::File.join(::File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift HOSTMANAGER_LIB_PATH

require 'rubygems'
require 'sinatra/base'
require 'dm-migrations'
require 'elasticbeanstalk/hostmanager'
require 'elasticbeanstalk/hostmanager/daemonmanager'
require 'elasticbeanstalk/hostmanager/models/event'
require 'elasticbeanstalk/hostmanager/models/filepublication'
require 'elasticbeanstalk/hostmanager/models/metric'
require 'elasticbeanstalk/hostmanager/models/state'
require 'elasticbeanstalk/hostmanager/models/version'
require 'elasticbeanstalk/hostmanager/log'

# On shutdown, stop the daemons
at_exit do 
  ElasticBeanstalk::HostManager.log "Stopping DaemonManager"
  ElasticBeanstalk::HostManager::DaemonManager.instance.stop
end

# Database setup
db_file = "sqlite3://#{DATABASE_PATH}/hostmanager.db"

ElasticBeanstalk::HostManager.log("Setting up SQLite DB: #{db_file}")

DataMapper.setup(:default, db_file)
DataMapper.finalize
DataMapper.auto_upgrade!

# Set the HM state to starting
ElasticBeanstalk::HostManager.state.transition_to(:starting, :metric => ElasticBeanstalk::HostManager::Metric.create('Startup'))

# Log an event that HM is starting
ElasticBeanstalk::HostManager::Event.store(:host_manager, 'Starting Host Manager', :info, [ :milestone, :host_manager ], false)

# Find all init files and load them
Dir[::File.expand_path(::File.join(HOSTMANAGER_LIB_PATH, 'elasticbeanstalk', 'hostmanager', 'init*.rb'))].uniq.each do |init_file|
  require init_file
end

# Run the web server
run ElasticBeanstalk::HostManager::Server

# Schedule the post init actions to start once EM reactor thread starts up
EM.schedule {
  # Start daemons
  ElasticBeanstalk::HostManager.log("Starting Daemon Manager")
  ElasticBeanstalk::HostManager::DaemonManager.instance.start
  
  # Run registered post-init blocks
  ElasticBeanstalk::HostManager::Server.post_init

  # Startup complete
  ElasticBeanstalk::HostManager.log("Host Manager startup complete")
  
  # Log an event that HM has started
  ElasticBeanstalk::HostManager::Event.store(:host_manager, 'Host Manager startup complete', :info, [ :milestone, :host_manager ], false)
}
