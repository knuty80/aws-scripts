#!/usr/bin/env bash
## Gets console output from an ec2 instance
## Pass the instance ID as the 1st argument or enter it when prompted
## Uses your default region unless you override it; Default is set to 

set -o errexit
set -o pipefail
#set -o xtrace

### Setting the default if no region is found or passed as arg2 input; Will ask for input!
no_default_region='us-east-1'

## Instance ID passed as arg1 or ask for it
instance_id=${1}
[ -z ${instance_id} ] && read -p 'Instance ID: ' instance_id

## Region passed as arg2 or look for it in AWS CLI config and ask the user to use or override it
region=${2}
if [ -z ${region} ]; then
    if [ ! -f '~/.aws/config' ]; then
		    region_default="$(grep 'region' ~/.aws/config | awk -F '=' '{print $2}' | head -1)"
		else
		    region_default="${no_default_region}"
	  fi
    ## Prompt user with default region or let them override it
    read -p "Region [$(echo ${region_default})]: " region
    [ -z ${region} ] && region=${region_default}
fi

## Execute the AWS CLI 'get-console-output' command
## Ref: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/get-console-output.html
aws ec2 get-console-output --region ${region} --instance-id ${instance_id} --output text

