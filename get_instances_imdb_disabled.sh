#!/usr/bin/env bash
## Copyright - Troy Knutson

#set -o xtrace
set -o pipefail
#set -o errexit

#### Enforce root/sudo rights
#if [[ $EUID > 0 ]]; then
#  echo "Please run as root/sudo"
#  exit 1
#fi

echo "Checking all regions for instances with the IMDS, metadata service disabled..."
regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)
for region in ${regions}
do
  echo "Checking in Region: ${region}"
  instances=$(aws ec2 describe-instances --region ${region} --query 'Reservations[].Instances[].InstanceId' --output text)
  for instance in ${instances}
  do
    if [ $(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].MetadataOptions[].HttpEndpoint' --output text) != "enabled" ]; then
      echo "Instance: ${instance} has the IMDS metadata service disabled"
    fi
  done
done

