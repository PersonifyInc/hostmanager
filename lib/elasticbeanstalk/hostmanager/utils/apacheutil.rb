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
        
        def self.log(msg, *args)
          HostManager.log msg
          Event.store(:apache, msg, *args)
        end

        def self.execute_httpd_cmd(verb, status_regex = /FAILED/)
          log("Executing Apache Command: #{verb}", :info, [ :milestone, :apache ], false)

          output = `/usr/bin/sudo /etc/init.d/httpd #{verb}`

          if ($?.exitstatus != 0 || output =~ status_regex)
            log("Apache #{verb} FAILED", :critical, [ :apache ])
          else
            log("Apache #{verb} succeeded", :info, [ :milestone, :apache ], false)
          end
        end

        def self.start
          execute_httpd_cmd('start')
        end

        def self.stop
          execute_httpd_cmd('stop')
        end

        def self.restart
          execute_httpd_cmd('graceful', /Starting httpd\: \[FAILED\]/)
        end

        def self.status
          `/usr/bin/sudo /etc/init.d/httpd status`.chomp
        end

        def self.update_httpd_conf(httpd_options = nil)
          return if httpd_options.nil?

          log('Updating Apache configuration', :info, [ :milestone, :apache ], false)

          # Make sure the document root is set and sanitized
          httpd_options['document_root'] = '' if httpd_options['document_root'].nil?
          httpd_options['document_root'] = '/' + httpd_options['document_root']
          httpd_options['document_root'].tap do |docroot|
            docroot.strip!
            docroot.squeeze!('/')
            docroot.chomp!('/')
            docroot.gsub!(/(?:\.\.\/|\.\/|[^\w\.\-\~\/])/, '_')
          end

          log('Writing Apache application configuration', :info, [ :milestone, :apache ], false)
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

          log('Apache vhosts configuration file failed to be written', :critical, [ :apache ]) unless ::File.exists?('/etc/httpd/sites/application')

          ElasticBeanstalk::HostManager.log(httpd_options)
        end
      end
    end
  end
end
