#!bin/bash
. ../.env
terraform output infisical_private_key | tail -n +2 | head -n -2 > scripts/infisical/infisical_private_key.pem
sudo chmod 400 scripts/infisical/infisical_private_key.pem