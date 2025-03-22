#!/bin/bash

# https://redis.io/docs/latest/operate/oss_and_stack/install/install-redis/install-redis-on-linux/
sudo apt-get install lsb-release curl gpg -y
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg -y
sudo chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
sudo apt-get update -y
sudo apt-get install -y redis

sudo systemctl enable redis-server
sudo systemctl start redis-server

# https://www.digitalocean.com/community/questions/enable-remote-redis-connection
# Configure Redis to bind to all interfaces
sudo sed -i 's/bind 127.0.0.1 -::1/bind 0.0.0.0/' /etc/redis/redis.conf

# Disable protected mode to allow remote connections
sudo sed -i 's/protected-mode yes/protected-mode no/' /etc/redis/redis.conf

# Apply the changes
sudo systemctl restart redis-server

# require a password to connect to the Redis server
redis-cli config set requirepass "password"

# Inform the user
echo "Redis configured to accept remote connections on all interfaces"
