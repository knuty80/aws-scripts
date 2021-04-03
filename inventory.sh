#!/usr/bin/env bash
## Copyright - Troy Knutson
## Finds all instances in each region, gets inventory info, and writes to CSV file

## Notes:
## - Lots of API calls, consider exponential backoff or uncommenting the sleep line

#set -o xtrace
set -o pipefail
#set -o errexit

csvFile="inventory-report-$(date +%Y-%m-%d).csv"

## Set CSV columns
echo 'Account,Region/AZ,Instance,State,Public DNS Name,Private DNS Name,Security Groups,Launch Time,Operating System' > ${csvFile}
## Loop through regions
for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)
do
  ## Loop through instances per region
  numberOfInstances=$(aws ec2 describe-instances --region ${region} --query 'Reservations[].Instances[].InstanceId' --output text | wc -w)
  if [ "${numberOfInstances}" -gt "0" ]; then
    echo "$(echo "$(date +%Y-%m-%d) $(date +%H:%M:%S%Z)") WARN: Running against $(echo ${numberOfInstances}) instances in ${region}..."
    for instance in $(aws ec2 describe-instances --region ${region} --query 'Reservations[].Instances[].InstanceId' --output text)
    do
      echo "$(echo "$(date +%Y-%m-%d) $(date +%H:%M:%S%Z)") INFO: Getting info on ${instance}"
      ## Put inventory values into variables that we can write to the CSV with
      accountId=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].OwnerId' --output text)
      amiId=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].ImageId' --output text)
      osDesc=$(aws ec2 describe-images --region ${region} --image-ids ${amiId} --query 'Images[].Description' --output text)
      publicDnsName=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].PublicDnsName' --output text)
      privateDnsName=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].PrivateDnsName' --output text)
      state=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].State.Name' --output text)
      az=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].Placement[].AvailabilityZone' --output text)
      sg=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].SecurityGroups[].GroupId' --output text)
      launchTime=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].LaunchTime' --output text)
      echo "${accountId},${az},${instance},${state},${publicDnsName},${privateDnsName},$(echo ${sg}),${launchTime},${osDesc}" >> ${csvFile}
      #sleep 30
    done
  fi
done
echo "$(echo "$(date +%Y-%m-%d) $(date +%H:%M:%S%Z)") INFO: Report complete! Output file:$(pwd)/${csvFile}"

