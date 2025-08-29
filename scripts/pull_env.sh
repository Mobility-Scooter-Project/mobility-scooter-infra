#!/bin/bash
infisical login --domain https://infisical.cis240470.projects.jetstream-cloud.org
infisical secrets --projectId 3204844a-4f4c-479e-b776-1d70588f696c --env prod --plain --tags local > .env

echo "Pulled latest .env from Infisical"