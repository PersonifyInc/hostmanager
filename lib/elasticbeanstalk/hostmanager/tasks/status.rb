# -*- coding: utf-8 -*-
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

module ElasticBeanstalk
  module HostManager
    module Tasks

      class Status < Task
        @@last_request = DateTime.now
        @@time_format  = '%Y-%m-%dT%H:%M:%S %z'

        def run
          results = filter_results(@parameters['filter'])

          @@last_request = DateTime.now unless @parameters['readOnly']
          
          generate_response(:ok, results)
        end

        private

        def filter_results(filter=nil)
          now = DateTime.now
          results = {}

          results[:events]       = events(now)  if filter.nil? || filter.include?('events')
          results[:publications] = publications if filter.nil? || filter.include('publications')
          results[:metrics]      = metrics      if filter.nil? || filter.include('metrics')
          results[:versions]     = versions     if filter.nil? || filter.include('versions')

          results
        end

        def events(end_date=DateTime.now)
          events = []

          Event.all(:timestamp => @@last_request..end_date).each do |event|
            events << { 
              :timestamp => event.timestamp.strftime(@@time_format),
              :source    => event.source,
              :message   => event.message,
              :severity  => event.severity,
              :tags      => event.tags,
              :customer_visible => event.customer_visible
            }
          end

          events
        end

        def publications
          publications = []

          publish = (ElasticBeanstalk::HostManager.config.elasticbeanstalk && 
                     ElasticBeanstalk::HostManager.config.elasticbeanstalk['HostManager'] && 
                     ElasticBeanstalk::HostManager.config.elasticbeanstalk['HostManager']['LogPublicationControl'])

          if (publish && (publish.casecmp("true") == 0))
            FilePublication.all(:state => :pending).each do |filepub|
              publications << {
                :filename => filepub.filename,
                :path     => 'logs' ### TODO: Store in database and use that path
              }
            end
          end

          publications
        end

        def metrics
          metrics = []

          Metric.all(:emitted => false).each do |metric|
            # Inject the current container and instance type into the metric
            metric.metrics_properties['Container']    = ElasticBeanstalk::HostManager.config.container_type
            metric.metrics_properties['InstanceType'] = ElasticBeanstalk::HostManager.config.instance_type
            
            metrics << metric.emit
          end

          metrics
        end

        def versions
          latest_app_version = Version.last(:type => :application)
          app_version_info = latest_app_version.nil? ? {} : latest_app_version.to_info

          {
            :application => app_version_info,
            :hostmanager => { :version => ElasticBeanstalk::HostManager.version }
          }
        end
      end # Status class

    end # Tasks module
  end # HostManager module
end # ElasticBeanstalk module
