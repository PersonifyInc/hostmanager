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

require 'singleton'
require 'uuidtools'

module ElasticBeanstalk
  module HostManager

    class DeploymentManager
      @current_deployments  = {}
      @pending_healthchecks = {}

      def self.should_deploy(application)
        return false if application.nil?
        return false if application.version_info.deployed

        return true
      end

      def self.deploy(application)        
        return if application.nil?

        if (application.version_info.deployed)
          HostManager.log "Application version #{application.version_info.version} is already deployed"
          return
        end
        # Update HM state if not starting up
        HostManager.state.transition_to(:updating_application, :metric => Metric.create('UpdateApplication')) unless HostManager.state.current == :starting

        # Create a new deployment for the app
        deployment = Deployment.new(application)

        # Store it in current deployments
        @current_deployments[application.version_info.version] = deployment

        # Start the deployment
        deployment.run
      end

      def self.cleanup_deployment(version)
        return if version.nil? || @current_deployments[version].nil?

        # Remove this deployment
        @current_deployments.delete(version)

        # Set HM state to ready
        HostManager.state.transition_to(:ready) { |state|
          unless (state.context[:metric].nil?)
            state.context[:metric].end_time = DateTime.now
            state.context[:metric].save
          end
        }
      end

      def self.complete_deployment(version)
        return if version.nil? || @current_deployments[version].nil?

        # Remove from current deployments, emit metric
        cleanup_deployment(version)

        # Pending HC timestamp
        @pending_healthchecks[version] = Time.now
      end

      # Confirms there has been a successful healthcheck for an application version,
      # defaults to the currently deployed app version
      def self.healthcheck_success(app_version=HostManager.config.application_version)
        return if app_version.nil? || @pending_healthchecks[app_version.version].nil?

        time_to_success = (Time.now - @pending_healthchecks[app_version.version]) * 1000

        # Remove version from pending hc
        @pending_healthchecks.delete(app_version.version)

        # Store an event for the success
        Event.store("DeploymentManager.#{HostManager.state.current}", "First successful healthcheck since application version #{app_version.version} was deployed: #{time_to_success}ms", :info, [ :milestone, :healthcheck ], false)

        # Emit a healthcheck metric
        metric = Metric.create('Healthcheck')
        metric.timings['FirstELBHealthcheckSuccess'] = time_to_success
        metric.end_time = DateTime.now
        metric.save
      end

      def self.deployment_status(version)
        @current_deployments[version].state unless @current_deployments[version].nil?
      end
    end

    class Deployment
      attr_reader   :application
      attr_accessor :state

      class << self
        attr_reader :available_states
      end

      @available_states = [ :pending_deployment, :pre_deployment, :deploying, :post_deployment, :pending_healthcheck, :deployed, :error ]

      def self.valid_state?(state)
        @available_states.contains?(state)
      end

      def initialize(application)
        # Start off pending deployment
        @state = :pending_deployment

        # Application to deploy
        @application = application

        # Use the same source for all Events related to this deployment
        @event_source = "DeploymentManager.#{HostManager.state.current}"

        # Tags for Events
        @event_tags = [ :milestone, :deployment, create_application_tag ]
      end

      def run
        # Store an event for the start of the application deployment
        Event.store(@event_source, "Starting application version #{@application.version_info.version} deployment", :info, @event_tags, false)

        # Deployment block for EM
        deploy_op = proc {
          begin
            # Set deployment state to pre_deployment
            @state = :pre_deployment
            @application.pre_deploy

            # Start deployment
            @state = :deploying
            @application.deploy

            # Post deployment
            @state = :post_deployment
            @application.post_deploy
            
            # Store an event for success, put into pending healthcheck
            Event.store(@event_source, "Application version #{@application.version_info.version} deployment complete, pending healthcheck", :info, @event_tags, false)
            @state = :deployed

            # Update app's version info to say deployed
            @application.version_info.update(:deployed => true, :timestamp => Time.now.utc, :error => '')

            # Complete deployment
            DeploymentManager.complete_deployment(@application.version_info.version)
          rescue DeployException => ex
            HostManager.log "Application version #{@application.version_info.version} deployment failed: #{ex.message}\nOutput: #{ex.output}"

            # Emit a customer-visible event that the deployment failed
            Event.store(@event_source, ex.message, :warn, [ :deployment, :error ])

            # Store the output from the failed script in the DB
            @application.version_info.update(:error => ex.output)

            # Set deployment state
            @state = :error

            # Wrapup deployment
            DeploymentManager.cleanup_deployment(@application.version_info.version)
          end
        }

        # Run the deployment in one of EM's threads
        EM.defer(deploy_op)
      end

      private

      def create_application_tag
        @application.class.name.split('::').last
      end
    end

    # Deployment exception for storing any script output
    class DeployException < Exception
      attr_accessor :output
    end

  end
end
