#!/usr/bin/env bash
## Copyright - Troy Knutson
## Enables EBS encryptionn by default in all regions

#set -o xtrace
#set -o pipefail
#set -o errexit

## Loop through all regions
for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)
do
  aws ec2 enable-ebs-encryption-by-default --region ${region} | grep "true" > /dev/null 2>&1
  [ $? -eq "0" ] && echo "$(echo $(date +%Y-%m-%d) $(date +%H:%M:%S%Z)) INFO: EBS encryption enabled by default in ${region}"
done

