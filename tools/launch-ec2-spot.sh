#!/usr/bin/env bash
set -euo pipefail

echo "=== Launching eGixium Full AWS EC2 Spot Builder ==="

GH_TOKEN=$(gh auth token)

# Prepare User Data Script from build-full-ec2.sh
USER_DATA=$(cat /root/chromium-extend/tools/build-full-ec2.sh | sed "s|__GH_TOKEN__|${GH_TOKEN}|g")
ENCODED_USER_DATA=$(echo "$USER_DATA" | base64 -w 0)

# 200 GB GP3 EBS storage for Chromium build tree
BLOCK_DEVICE='[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":200,"VolumeType":"gp3","DeleteOnTermination":true}}]'
SPOT_OPTIONS='{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time","InstanceInterruptionBehavior":"terminate"}}'

for itype in "c6a.8xlarge" "m6a.8xlarge" "c5a.8xlarge" "m5a.8xlarge" "c6i.8xlarge"; do
    echo "Attempting Spot launch with ${itype} (32 vCPUs, 64+ GB RAM)..."
    if aws ec2 run-instances \
        --image-id ami-06e78a71af43ef21a \
        --instance-type "${itype}" \
        --instance-initiated-shutdown-behavior terminate \
        --instance-market-options "${SPOT_OPTIONS}" \
        --block-device-mappings "${BLOCK_DEVICE}" \
        --user-data "${ENCODED_USER_DATA}" \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=eGixium-Cloud-Builder}]' \
        --output json > /tmp/ec2_launch_output.json 2>/dev/null; then
        
        INSTANCE_ID=$(python3 -c "import json; print(json.load(open('/tmp/ec2_launch_output.json'))['Instances'][0]['InstanceId'])")
        echo "SUCCESS! Launched EC2 Spot Instance: ${INSTANCE_ID} (${itype})"
        echo "The full compilation is now running in AWS cloud."
        echo "When finished, the APK will be uploaded to GitHub Releases and the instance will auto-terminate."
        exit 0
    fi
done

echo "Error: Could not launch Spot instance across candidate types."
exit 1
