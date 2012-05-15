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

require 'dm-timestamps'

module ElasticBeanstalk
  module HostManager

    # Very basic state tracking for Host Manager
    class State
      include DataMapper::Resource

      attr_reader :context

      property :id,         Serial
      property :state,      Enum[ :unknown, :starting, :ready, :updating_application, :updating_configuration ], :default => :unknown
      property :created_at, DateTime
      property :updated_at, DateTime

      def initialize(attributes={}, &block)
        super(attributes, &block)
        @context = {}
      end

      def current
        return @state
      end

      def transition_to(state, context=nil)
        HostManager.log "Transitioning from #{@state} to #{state}"
        @state = state
        @updated_at = Time.now
        save

        @context.merge!(context) unless context.nil?

        yield self if block_given?
      end
    end

  end
end
