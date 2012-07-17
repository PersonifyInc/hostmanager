#!/bin/bash
echo 'Stopping HostManager'
service hostmanager stop
echo 'Removing old HostManager source'
rm -rf /opt/elasticbeanstalk/srv/hostmanager
echo 'Copy new HostManager source'
cp -R . /opt/elasticbeanstalk/srv/hostmanager
echo 'Fix permissions'
chown -R elasticbeanstalk:elasticbeanstalk /opt/elasticbeanstalk/srv/