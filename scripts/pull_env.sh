#!/bin/bash
infisical login --domain https://infisical.cis240470.projects.jetstream-cloud.org
infisical secrets --projectId 39289be1-c99e-4f3c-badc-bcfc0ea959a6 --env prod --plain --tags local > .env

echo "Pulled latest .env from Infisical"