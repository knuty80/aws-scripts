#!/usr/bin/env bash
## Copyright - Troy Knutson
## Finds all instances in each region, gets inventory info, and writes to CSV file

## Notes:
## - Lots of API calls, consider exponential backoff or uncommenting the sleep line

#set -o xtrace
set -o pipefail
#set -o errexit

csvFile='inventory-report.csv'

## Set CSV columns
echo 'Region,Availability Zone,Instance,State,Public DNS Name,Private DNS Name,Security Groups,Launch Time,Operating System' > ${csvFile}
## Loop through regions
for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)
do
  ## Loop through instances per region
  for instance in $(aws ec2 describe-instances --region ${region} --query 'Reservations[].Instances[].InstanceId' --output text)
  do
    ## Put inventory values into variables that we can write to the CSV with
    publicDnsName=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].PublicDnsName' --output text)
    privateDnsName=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].PrivateDnsName' --output text)
    state=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].State.Name' --output text)
    az=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].Placement[].AvailabilityZone' --output text)
    sg=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].SecurityGroups[].GroupId' --output text)
    launchTime=$(aws ec2 describe-instances --region ${region} --instance-ids ${instance} --query 'Reservations[].Instances[].LaunchTime' --output text)
    [ -n ${publicDnsName} ] && addressPub="${publicDnsName}"
    [ -n ${privateDnsName} ] && addressPriv="${privateDnsName}"
    curl http://${publicDnsName}:22 > /dev/null 2>&1;  [ $? -eq 56 ] && sshAddress="${publicDnsName}"
    curl http://${privateDnsName}:22 > /dev/null 2>&1; [ $? -eq 56 ] && sshAddress="${privateDnsName}"
    os="$(ssh ${sshAddress} hostnamectl | grep 'Operating System' | awk -F ': ' '{print $NF}')"
    ## Create entry in CSV for each instance
    echo "${region},${az},${instance},${state},${publicDnsName},${privateDnsName},$(echo ${sg}),${launchTime},${os}" >> ${csvFile}
    #sleep 30
  done
done

