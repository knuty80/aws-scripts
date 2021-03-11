#!/usr/bin/env bash
## Copyright by Troy Knutson

#set -o xtrace
set -o errexit
set -o pipefail

#### IMPORTANT ####
## 1) Edit the value for the  KMS key, kmsKeyId='', that you wish to use for encryption on the new volumes.
## 2) Edit the "volumes+=([<instance-id>]=volume-id)" line with a test instance to run the script against, for validation. Use a space as the delimiter for a fleet.
## NOTES: You should create an instance with an unencrypted volume, setup this script to run against it, alone, validate it works as expected, then add all the instances in the array.

## Variables
kmsKeyId='xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
declare -A volumes
#volumes+=([instance-id]=volume-id)
#volumes+=([instance-id]=volume-id [instance-id]=volume-id [instance-id]=volume-id [instance-id]=volume-id [instance-id]=volume-id)

## Iterate over each instance in the array, stop instance, take snapshot, create new encrypted volume from snapshot, detach unencrypted volume, attach new encrypted volume, and start the instance
for instance in "${!volumes[@]}"
do
  echo "*** START: Volume: ${volumes[$instance]}"
  instanceId=$(aws ec2 describe-volumes --volume-ids ${volumes[$instance]} --query 'Volumes[*].{InstanceId:Attachments[*].InstanceId}' | grep 'i-' | awk -F '"' '{print $2}')
  volId=$(aws ec2 describe-volumes --volume-ids ${volumes[$instance]} --query 'Volumes[*].{VolumeId:VolumeId}' | grep 'vol-' | sed 's/"//g' | sed 's/,//' | awk '{print $NF}')
  volAz=$(aws ec2 describe-volumes --volume-ids ${volumes[$instance]} --query 'Volumes[*].{AvailabilityZone:AvailabilityZone}' | grep 'Avail' | sed 's/"//g' | sed 's/,//' | awk '{print $NF}')
  volType=$(aws ec2 describe-volumes --volume-ids ${volumes[$instance]} --query 'Volumes[*].{VolumeType:VolumeType}' | grep Vol | awk -F '"' '{print $4}') # | sed 's/"//g' | awk '{print $1}')
  volSize=$(aws ec2 describe-volumes --volume-ids ${volumes[$instance]} --query 'Volumes[*].{Size:Size}' | grep 'Size' | sed 's/"//g' | sed 's/,//' | awk '{print $NF}')
  volIops=$(aws ec2 describe-volumes --volume-ids ${volumes[$instance]} --query 'Volumes[*].{Iops:Iops}' | grep 'Iops' | sed 's/"//g' | sed 's/,//' | awk '{print $NF}')
  deviceName=$(aws ec2 describe-volumes --volume-ids ${volumes[$instance]} --query 'Volumes[*].{Device:Attachments[*].Device}' | grep '/dev' | awk -F '"' '{print $2}')
  echo "*** INFO: instance-id:${instanceId} volume-id:${volId} availability-zone:${volAz} volume-type:${volType} volume-size:${volSize} volume-iops:${volIops} kms-key-id:${kmsKeyId} device-name:${deviceName}"

  ## Great place to validate that the variables are working correctly...
  #exit 0

  ## Stop the instance and wait until stopped
  aws ec2 stop-instances --instance-ids ${instance}
  while [[ ! $(aws ec2 describe-instances --instance-ids ${instance} --query 'Reservations[*].Instances[*].State' | grep Name | awk -F '"' '{print $4}') == 'stopped' ]]
  do
    sleep 2
  done

  ## Create a snapshot of the EBS volume, capture the snapshot ID as a variable, and wait until it completes
  snapshotId=$(aws ec2 create-snapshot --volume-id ${volumes[$instance]} | grep SnapshotId | awk -F '"' '{print $4}')
  echo "*** Snapshot-id: ${snapshotId}"
  echo "Waiting until snapshot is completed..."
  while [[ ! $(aws ec2 describe-snapshots --snapshot-id ${snapshotId} | grep State | awk -F '"' '{print $4}') == "completed" ]]
  do
    sleep 5
  done

  ## Detach source EBS volume, create a new volume, restoring the snapshot, and encrypting it
  aws ec2 detach-volume --volume-id ${volumes[$instance]}
  if [ ${volType} == 'gp2' ]; then
      ## iops value not supported
      newVolumeId=$(aws ec2 create-volume --availability-zone ${volAz} --encrypted --kms-key-id ${kmsKeyId} --size ${volSize} --volume-type ${volType} --snapshot-id ${snapshotId} | grep VolumeId | awk -F '"' '{print $4}')
  else
      ## Specify IOPS based on source volume
      newVolumeId=$(aws ec2 create-volume --availability-zone ${volAz} --encrypted --kms-key-id ${kmsKeyId} --size ${volSize} --volume-type ${volType} --iops ${volIops} --snapshot-id ${snapshotId} | grep VolumeId | awk -F '"' '{print $4}')
  fi

  ## Wait for the new, encrypted, volume to be available
  while [[ ! $(aws ec2 describe-volumes --volume-id ${newVolumeId} | grep State | awk -F '"' '{print $4}') == 'available' ]]
  do
    sleep 5
  done

  ## Attach the new volume to the instance as the same device name
  aws ec2 attach-volume --volume-id ${newVolumeId} --instance-id ${instanceId} --device ${deviceName}

  ## Start the instance, with the new encrypted volume and wait until it's in the running state
  aws ec2 start-instances --instance-ids ${instanceId}
  while [[ ! $(aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[*].Instances[*].State' | grep Name | awk -F '"' '{print $4}') == 'running' ]]
  do
    sleep 2
  done
  echo "*** END: A snapshot of volume: ${volumes[$instance]} was taken and used to create and attach an encrypted volume: ${newVolumeId} on instance: ${instanceId} successfully"
done

