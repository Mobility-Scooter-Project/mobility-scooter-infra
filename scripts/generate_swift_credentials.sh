#!/bin/bash
. ./.env

# Create credentials and capture output
output=$(openstack ec2 credentials create)

# Extract access and secret values
access=$(echo "$output" | grep "| access" | awk '{print $4}')
secret=$(echo "$output" | grep "| secret" | awk '{print $4}')

# Append to .env file
echo "" >> .env
echo "TF_VAR_AWS_ACCESS_KEY_ID=$access" >> .env
echo "TF_VAR_AWS_SECRET_ACCESS_KEY=$secret" >> .env

echo "Credentials added to .env file:"
echo "AWS_ACCESS_KEY_ID=$access"
echo "AWS_SECRET_ACCESS_KEY=$secret"