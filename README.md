# HostManager (AWS) - extended

## Overview

The goal of this project is to extend Amazon's HostManger application to support additional application types with custom configurations that are not enabled through the stock app.

Why?  Because ElasticBeanstalk is a nice service and I want to use it with other application stacks, many of which will never be supported by Amazon directly.

When this is finished, you should be able to drop it in to any existing Amazon Linux AMI and, with a few small tweaks to the environment config, be up and running.

## Project Organization

Stock HostManager basically just supports a webroot directory.  This extended version supports several directories in the application source:

- webroot
	(your application source)

- config
	(various config files for HostManager)

- (additional options depending on supported platforms)

## Platform Support

The restructuring of this code should enable the support of any arbitrary application stack, but it will ship with the following included by default:

- Python (wsgi)
- Python (tornadio)
- Wowza Media Server
- PHP (obviously)

## Your Application

A basic application should consist of the following:

- config
	- deploy.sh (copy files, fix permissions, etc.)
	- post-deploy.sh (optional)
	- config.sh (optional, updates custom config vars)
	- shutdown.sh (stop app servers)
	- startup.sh (start app servers)
- application source (anything!)

## Installing custom HostManager
1. Launch an existing Beanstalk AMI in EC2 (NOT THROUGH BEANSTALK)
2. Zip up this directory
3. Use wget or scp to move it to your server
4. Unzip and enter directory
5. Add execute perms to deploy.sh and run
6. Use EC2 to roll a new AMI
7. Done!