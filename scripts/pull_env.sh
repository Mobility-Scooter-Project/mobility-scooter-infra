#!/bin/bash
infisical login --domain http://infisical.cis240470.projects.jetstream-cloud.org
infisical secrets --projectId 6b6bec38-9035-4fdd-a8c3-376af197b0c0 --env prod --plain --tags local | grep -v ".env=" > .env

echo "Pulled latest .env from Infisical"