#!/bin/bash
#
#	This script is run when the UpdateConfiguration task is executed.
#   It expects a sequence of arguments in the following form:
#	PARAM3="" PARAM4="" PARAM1="" PARAM2="" AWS_SECRET_KEY="" PARAM5="" AWS_ACCESS_KEY_ID=""
#
#	First, we parse the arguments into variables.  DO NOT MODIFY THIS.
param1=${3//PARAM1=/}
param2=${4//PARAM2=/}
param3=${1//PARAM3=/}
param4=${2//PARAM4=/}
param5=${5//PARAM5=/}
aws_key_id=${7//AWS_ACCESS_KEY_ID=/}
aws_secret=${6//AWS_SECRET_KEY=/}

#	Now you can use these variables!  We'll just echo them for testing.

# PARAM1

echo PARAM1: $param1

# PARAM2

echo PARAM2: $param2

# PARAM3

echo PARAM3: $param3

# PARAM4

echo PARAM4: $param4

# PARAM5

echo PARAM5: $param5

# AWS_ACCESS_KEY_ID

echo AWS_ACCESS_KEY_ID: $aws_key_id

# AWS_SECRET_KEY

echo AWS_SECRET_KEY: $aws_secret