require 'elasticbeanstalk/hostmanager/tasks/task'
require 'elasticbeanstalk/hostmanager/utils/apacheutil'

module ElasticBeanstalk
  module HostManager
    module Tasks

      class RestartAppServer < Task
        def run
          # Bluepill will restart Apache
          ElasticBeanstalk::HostManager::Utils::ApacheUtil.stop

          generate_response(:deferred)
        end
      end # RestartAppServer class
      
    end # Tasks module
  end # HostManager module
end # ElasticBeanstalk module
