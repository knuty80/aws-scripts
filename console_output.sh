#!/usr/bin/env bash
## Gets console output from an ec2 instance
## Pass the instance ID as the 1st argument or enter it when prompted
## Uses your default region unless you override it; Default is set to us-west-2

set -o errexit
set -o pipefail
#set -o xtrace

## Setting the default if no region is found or passed as arg2 input
no_region_default='us-west-2'

#### Ensure two and only two args are passed
## Instance ID
instanceId="${1}"
## Default AWS region
[ ! -f "~/.aws/config" ] && region="$(grep 'region' ~/.aws/config | awk -F '=' '{print $2}' | head -1)" || region=${2:-${no_region_default}}

## Ask for the instance ID and the region, if they are not passed as args; arg1=instance_id arg2=region
[ ! -z "$1" ] || read -p 'Instance ID: ' instanceId
[ -n ${region} ] && read -p "Region [$(echo ${no_region_default})]: " region
## region defaults to 'no_region_default' variable defined above, if region input from user is blank
[ -n ${region} ] && region=${no_region_default}

aws ec2 get-console-output --region ${region} --instance-id ${instanceId} --output text

