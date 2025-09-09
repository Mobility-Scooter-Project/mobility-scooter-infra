#!bin/bash
START=$(date +%s)
echo "Running Terraform..."
. ./.env
cd infra && terraform apply -auto-approve
echo "Terraform applied successfully after $(( $(date +%s) - $START )) seconds."