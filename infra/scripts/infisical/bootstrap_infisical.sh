#!bin/bash
START=$(date +%s)
echo "Bootstrapping Infisical..."
HOST=infisical.cis240470.projects.jetstream-cloud.org

sh ./scripts/infisical/get_infisical_pk.sh
ssh -i ./scripts/infisical/infisical_private_key.pem ubuntu@$HOST < ./scripts/infisical/bootstrap_infisical_remote.sh

echo "Finished bootstrapping Infisical after $(( $(date +%s) - $START )) seconds."