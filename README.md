# HostManager (AWS) - extended

## Overview

HostManager is a small Ruby app that runs on each EC2 node in an Elastic 
Beanstalk environment.  It processes HTTP requests containing commands 
from the Elastic Beanstalk service.  These commands include things like
status checks, configuration updates, app deployments, etc.

The goal of this project is to extend Amazon's HostManger application to 
support additional application types with custom configurations that are 
not enabled through the stock app.

Why?  Because ElasticBeanstalk is a nice service and I want to use it 
with other application stacks, many of which will never be supported 
by Amazon directly.

## Project Organization

Stock HostManager basically just supports a webroot directory.  This 
extended version supports completely custom configurations by giving YOU 
control over the deployment process.  All you need to do is ship your 
application with a config directory filled with custom hooks for deployment
and startup/shutdown of custom server processes.

## Platform Support

Anything!  Well, sort of.  The default build is still designed to work with 
Apache running on port 80.  This is *required* because we need to proxy the 
Elastic Beanstalk HTTP requests to the HostManager application, which is 
running on a higher port.  It should be pretty easy to replace Apache with
another webserver, like nginx, if that's desired.

## Your Application

A basic application should consist of the following:

- beanstalk
	- deploy.sh (copy files, fix permissions, etc.)
	- post-deploy.sh (optional)
	- config.sh (optional, updates custom config vars)
	- shutdown.sh (stop app servers)
	- startup.sh (start app servers)
- application source (anything!)

There's an example included that demonstrates deploying a simple PHP
sample application - basically the same one that AWS uses.  You can use
this as a foundation for deploying other custom apps.

## Installing custom HostManager package

1. Launch an existing Beanstalk AMI in EC2 (NOT THROUGH BEANSTALK)
2. Zip up this directory
3. Use wget or scp to move it to your server
4. Unzip and enter directory
5. Add execute perms to deploy.sh and run
6. Use EC2 to roll a new AMI
7. Done!