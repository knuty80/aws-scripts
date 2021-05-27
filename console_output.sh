#!/usr/bin/env bash
## Gets console output from an ec2 instance
## Pass the instance ID as the 1st argument or enter it when prompted
## Uses your default region unless you override it; Default is set to
## Usage example: bash console_output.sh i-123456789 us-west-2

set -o errexit
set -o pipefail
#set -o xtrace

### Setting the default if no region is found or passed as arg2 input
no_default_region='us-east-1'

## Instance ID passed as arg1 or ask for it; Exits if no ID provided
instance_id=${1}
[ -z ${instance_id} ] && read -p 'Instance ID: ' instance_id
if [ -z ${instance_id} ]; then
    echo "An "Instance ID" must be set"
		exit 1
fi

## Region passed as arg2 or look for it in AWS CLI config and ask the user to use or override it
region=${2}
if [ -z ${region} ]; then
    ## set region_default to AWS CLI configured region or the value of the 'no_default_region' varibale above
    [ -f '~/.aws/config' ] && region_default="${no_default_region}" || region_default="$(grep 'region' ~/.aws/config | awk -F '=' '{print $2}' | head -1)"
    ## Prompt user with default region or let them override it
    read -p "Region [$(echo ${region_default})]: " region
    [ -z ${region} ] && region=${region_default}
fi

## Execute the AWS CLI 'get-console-output' command
## Ref: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/get-console-output.html
aws ec2 get-console-output --region ${region} --instance-id ${instance_id} --output text

