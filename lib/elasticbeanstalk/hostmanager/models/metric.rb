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
require 'dm-core'

module ElasticBeanstalk
  module HostManager

    class Metric
      include DataMapper::Resource

      property :id,                 Serial
      property :operation_name,     String
      property :timestamp,          DateTime
      property :start_time,         DateTime
      property :end_time,           DateTime
      property :counters,           Json
      property :timings,            Json
      property :metrics_properties, Json
      property :emitted,            Boolean, :default => false

      @@time_format  = '%Y-%m-%dT%H:%M:%S %z'

      def self.create(operation_name)
        return if operation_name.nil? || operation_name.empty?

        new(
          :operation_name => operation_name,
          :start_time => DateTime.now,
          :timestamp => DateTime.now,
          :counters => {},
          :timings => {},
          :metrics_properties => {}
        )
      end

      def emit
        # Must use save instead of update because this instance my have been updated elsewhere.
        attribute_set('emitted', true)
        save()

        {
          'OperationName' => operation_name,
          'StartTime'     => start_time.strftime(@@time_format),
          'EndTime'       => end_time.strftime(@@time_format),
          'Counters'      => counters,
          'Timings'       => timings,
          'Properties'    => metrics_properties,
          'timestamp'     => timestamp.strftime(@@time_format)
        }
      end
    end # Metric class

  end # HostManager module
end # ElasticBeanstalk module
