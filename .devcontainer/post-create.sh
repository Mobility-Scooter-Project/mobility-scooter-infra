#!/bin/bash
sudo apt-get update -y
sudo apt install python3-openstackclient -y

# install subclients
sudo apt install python3-swiftclient python3-magnumclient python3-keystoneclient python3-barbicanclient -y