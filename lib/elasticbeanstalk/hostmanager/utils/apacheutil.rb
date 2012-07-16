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
    module Utils

      class ApacheUtil
        def self.start
          # Log event for Apache start
          Event.store(:apache, 'Starting Apache', :info, [ :milestone, :apache ], false)
          HostManager.log 'Starting Apache'

          output = `/usr/bin/sudo /etc/init.d/httpd start`

          if ($?.exitstatus != 0 || output =~ /FAILED/)
            HostManager.log 'Apache failed to start'
            Event.store(:apache, 'Apache failed to start', :critical, [ :apache ])
          else
            # Log event for Apache startup completion
            HostManager.log 'Apache started'
            Event.store(:apache, 'Apache startup complete', :info, [ :milestone, :apache ], false)
          end
        end

        def self.stop
          Event.store(:apache, 'Stopping Apache', :info, [ :milestone, :apache ], false)
          HostManager.log 'Stopping Apache'
          output = `/usr/bin/sudo /etc/init.d/httpd stop`

          if ($?.exitstatus != 0 || output =~ /FAILED/)
            HostManager.log 'Apache failed to stop'
            Event.store(:apache, 'Apache failed to stop', :critical, [ :apache ])
          else
            HostManager.log 'Apache stopped'
            Event.store(:apache, 'Apache stopped', :info, [ :apache ], false)
          end
        end

        def self.restart
          Event.store(:apache, 'Restarting Apache', :info, [ :milestone, :apache ], false)
          HostManager.log 'Restarting Apache'
          output = `/usr/bin/sudo /etc/init.d/httpd graceful`

          # Check the last line of the response
          if ($?.exitstatus != 0 || output.lines.to_a.last =~ /FAILED/)
            HostManager.log 'Apache failed to restart'
            Event.store(:apache, 'Apache failed to restart', :critical, [ :apache ])
          else
            HostManager.log 'Apache restarted'
            Event.store(:apache, 'Apache restarted', :info, [ :apache ], false)
          end
        end

        def self.status
          `/usr/bin/sudo /etc/init.d/httpd status`.chomp
        end

        def self.update_httpd_conf(httpd_options)
          return if httpd_options.nil?

          Event.store(:apache, 'Updating Apache configuration', :info, [ :milestone, :apache ], false)
          HostManager.log 'Updating Apache configuration'

          # Make sure the document root is set and sanitized
          httpd_options['document_root'] = '' if httpd_options['document_root'].nil?
          httpd_options['document_root'] = '/' + httpd_options['document_root']
          httpd_options['document_root'].tap do |docroot|
            docroot.strip!
            docroot.squeeze!('/')
            docroot.chomp!('/')
            docroot.gsub!(/(?:\.\.\/|\.\/|[^\w\.\-\~\/])/, '_')
          end

          # Write the vhosts information to a file
          Event.store(:apache, 'Writing Apache application configuration', :info, [ :milestone, :apache ], false)
          vhosts_file = ::File.open('/etc/httpd/sites/application', 'w') do |file|
          file.puts <<-VHOSTS
NameVirtualHost *:80

<VirtualHost *:80>
    DocumentRoot /var/www/html#{httpd_options['document_root']}
    LogFormat "%h %l %u %t \\"%r\\" %>s %b \\"%{Referer}i\\" \\"%{User-Agent}i\\"" combined
    LogFormat "%{X-Forwarded-For}i %l %u %t \\"%r\\" %>s %b \\"%{Referer}i\\" \\"%{User-Agent}i\\"" proxy
    SetEnvIf X-Forwarded-For "^.*\\..*\\..*\\..*" forwarded
    CustomLog "/var/log/httpd/application-access_log" combined env=!forwarded
    CustomLog "/var/log/httpd/application-access_log" proxy env=forwarded
    ErrorLog /var/log/httpd/application-error_log

    <Directory "/var/www/html#{httpd_options['document_root']}">
        Options Indexes FollowSymLinks
        AllowOverride All
        Order allow,deny
        Allow from all
    </Directory>

    ## Setup proxy to redirect to HostManager for ELB Health Check
    <Proxy *>
        Order deny,allow
        Allow from all
    </Proxy>

    ProxyPass /_hostmanager http://localhost:8999 retry=0
    ProxyPassReverse /_hostmanager http://localhost:8999

    ## Add an exclusion for the host manager communication so that it doesn't get globbed into the / proxypass
    ProxyPass /_hostmanager !
</VirtualHost>
VHOSTS
          end

          unless ::File.exists?('/etc/httpd/sites/application')
            HostManager.log "Apache vhosts configuration file failed to be written"
            Event.store(:apache, 'Apache vhosts configuration file failed to be written', :critical, [ :apache ])
          end

          `sudo apachectl -k stop` # Kill other Apache processes that sometimes interfere
          output = `/usr/bin/sudo /etc/init.d/httpd restart`

          if ($?.exitstatus != 0 || output =~ /FAILED/)
            HostManager.log 'Apache failed to restart'
            HostManager.log output
            Event.store(:apache, 'Apache failed to restart', :critical, [ :apache ])
          else
            # Log event for Apache restart completion
            HostManager.log 'Apache restarted'
            Event.store(:apache, 'Apache restart complete', :info, [ :milestone, :apache ], false)
          end

          ElasticBeanstalk::HostManager.log(httpd_options)
        end
      end
    end
  end
end
