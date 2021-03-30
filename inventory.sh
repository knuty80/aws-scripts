#!/usr/bin/env bash
## Copyright - Troy Knutson
## Finds all instances in each region, gets inventory info, and writes to CSV file

## Notes:
## - Lots of API calls, consider exponential backoff or uncommenting the sleep line

#set -o xtrace
set -o pipefail
#set -o errexit

csvFile="inventory-report-$(date +%Y-%m-%d).csv"
date=$(echo "$(date +%Y-%m-%d) $(date +%H:%M:%S%Z)")

## Set CSV columns
echo 'Region/AZ,Instance,State,Public DNS Name,Private DNS Name,Security Groups,Launch Time,Operating System' > ${csvFile}
## Loop through regions
#for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)
for region in us-west-2
do
  ## Loop through instances per region
  numberOfInstances=$(aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' --output yaml | wc -l)
  echo "${date} WARN: Running against $(echo ${numberOfInstances}) instances..."
  for instance in $(aws ec2 describe-instances --region ${region} --query 'Reservations[].Instances[].InstanceId' --output text)
  do
    echo "${date} INFO: Getting info on ${instance} in ${region}"
    ## Put inventory values into variables that we can write to the CSV with
    publicDnsName=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].PublicDnsName' --output text)
    privateDnsName=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].PrivateDnsName' --output text)
    state=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].State.Name' --output text)
    az=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].Placement[].AvailabilityZone' --output text)
    sg=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].SecurityGroups[].GroupId' --output text)
    launchTime=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].LaunchTime' --output text)
    ## WIP - SSH to host and get more info - WIP
    #[ -n ${publicDnsName} ] && dnsAddress="${publicDnsName}" || dnsAddress="${privateDnsName}"
    #curl -v http://${dnsAddress}:22; [ $? -eq 56 ] && sshAddress="${publicDnsName}"
    #[ -n ${sshAddress} ] && os="$(ssh ${sshAddress} hostnamectl | grep 'Operating System' | awk -F ': ' '{print $NF}')"
    ## Create entry in CSV for each instance
    echo "${az},${instance},${state},${publicDnsName},${privateDnsName},$(echo ${sg}),${launchTime},${os}" >> ${csvFile}
    #sleep 30
  done
  echo "${date} INFO: Report complete! Report oputput:$(pwd)/${csvFile}"
done

