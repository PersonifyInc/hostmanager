require 'elasticbeanstalk/hostmanager/tasks/task'
require 'elasticbeanstalk/hostmanager/utils/apacheutil'

module ElasticBeanstalk
  module HostManager
    module Tasks

      class RestartAppServer < Task
        def run

          Event.store(:apache, 'Restarting the app server', :info, [ :milestone, :apache ], false)
          HostManager.log 'Restarting the app server'

          # Bluepill will restart Apache
          ElasticBeanstalk::HostManager::Utils::ApacheUtil.restart

          generate_response(:deferred)
        end
      end # RestartAppServer class

    end # Tasks module
  end # HostManager module
end # ElasticBeanstalk module
