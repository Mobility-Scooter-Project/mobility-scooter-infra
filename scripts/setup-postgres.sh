#!/bin/bash
set -e

sudo apt update
sudo apt install postgresql-client -y

# https://docs.timescale.com/self-hosted/latest/install/installation-docker/
docker pull timescale/timescaledb:2.18.1-pg17
sudo docker stop timescaledb && sudo docker rm timescaledb
docker run -d --name timescaledb -p 5432:5432 -e POSTGRES_PASSWORD=postgres timescale/timescaledb:2.18.1-pg17

sleep 5

docker exec -it timescaledb psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

# Clone the repository 
git clone https://github.com/Mobility-Scooter-Project/mobility-scooter-web-backend
cd mobility-scooter-web-backend
git checkout develop

# Install node 
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install node
nvm install 20.0.0

curl -fsSL https://get.pnpm.io/install.sh | sh -
source ~/.bashrc

export PATH="$HOME/.local/share/pnpm:$PATH"
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres

cd apps/api
pnpm i
pnpm  db:migrate