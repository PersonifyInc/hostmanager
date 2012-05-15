module ElasticBeanstalk
  module HostManager
    module Tasks

      class Unmanage < Task
        @@elasticbeanstalk_home  = '/opt/elasticbeanstalk'
        @@elasticbeanstalk_user  = 'elasticbeanstalk'
        @@elasticbeanstalk_group = 'elasticbeanstalk'
        @@hostmanager_dir = '/opt/elasticbeanstalk/srv/hostmanager'

        @@unmanage_script = <<-END_UNMANAGE_SCRIPT
#!/bin/bash
#{@@hostmanager_dir}/bin/hostmanager stop
/bin/sleep 5
#{@@elasticbeanstalk_home}/bin/bluepill quit
/etc/init.d/httpd stop
rm -f /etc/httpd/sites/hostmanager
/etc/init.d/httpd start
/bin/mv /etc/sudoers.orig /etc/sudoers
/usr/sbin/userdel -f #{@@elasticbeanstalk_user}
/usr/sbin/groupdel #{@@elasticbeanstalk_group}
/bin/rm -rf #{@@elasticbeanstalk_home}
/bin/rm /var/tmp/unmanage.sh
END_UNMANAGE_SCRIPT

        def run
          raise "Unmanage task has already been run" if File.exists?('/var/tmp/unmanage.log')

          File.open('/var/tmp/unmanage.sh', 'w+') { |f|
            f.puts @@unmanage_script
          }

          EM.system('chmod 755 /var/tmp/unmanage.sh')

          # Fork the unmanage script
          unmanage_process = 
            Process.fork do 
              `/bin/sleep 2; sudo /var/tmp/unmanage.sh >> /var/tmp/unmanage.log 2>&1`
            end

          # Detach the process from the Ruby kernel
          Process.detach(unmanage_process)
          
          generate_response(:deferred)
        end
      end # Unmanage class
      
    end # Tasks module
  end # HostManager module
end # ElasticBeanstalk module
