#!/bin/bash
#
# Locations:
# 	webroot: /var/www/html
#	deploy dir: /tmp/php-elasticbeanstalk-deployment
set -e

function logmsg() {
    echo $1
    /usr/bin/logger $1
}

if [ "$(ls -A /var/www/html)" ]; then
    logmsg "Nuking the old web root"
    /usr/bin/sudo rm -Rf /var/www/html/
    /usr/bin/sudo mkdir -p /var/www/html/
    /usr/bin/sudo chown -Rf elasticbeanstalk:elasticbeanstalk /var/www/html
    /usr/bin/sudo chmod -Rf 0755 /var/www/html
fi

logmsg "Moving new web root into place"
/usr/bin/sudo mv -n /tmp/php-elasticbeanstalk-deployment/application/webroot/* /var/www/html

logmsg "Fixing new app permissions"
/usr/bin/sudo /bin/chown -Rf elasticbeanstalk:elasticbeanstalk /var/www/html
/usr/bin/sudo /bin/chmod -Rf 0755 /var/www/html
/bin/find /var/www/html -type f -print0 | /usr/bin/xargs -0 /bin/chmod 0644