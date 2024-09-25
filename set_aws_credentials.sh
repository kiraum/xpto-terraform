#!/bin/bash

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset credentials

#aws configure
aws configure set region eu-central-1
aws configure set output json

aws configure list

# Get temporary credentials
#credentials=$(aws sts get-session-token --duration-seconds 3600)

# Extract the values
#export AWS_ACCESS_KEY_ID=$(echo $credentials | jq -r .Credentials.AccessKeyId)
#export AWS_SECRET_ACCESS_KEY=$(echo $credentials | jq -r .Credentials.SecretAccessKey)
#export AWS_SESSION_TOKEN=$(echo $credentials | jq -r .Credentials.SessionToken)

echo "Temporary credentials set. They will expire at $(echo $credentials | jq -r .Credentials.Expiration)"

aws iam list-roles
