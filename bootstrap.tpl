#!/bin/bash

# Update the system and install Docker and Git
sudo apt update -y
sudo apt install -y docker.io git

# Add the current user to the docker group
sudo groupadd docker

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add all existing users to the docker group
for user in $(getent passwd | cut -d: -f1); do
    sudo usermod -aG docker $user
done

# Docker permissions
sudo chmod 666 /var/run/docker.sock

# Download your project's files to the instance
cd ~ || exit
git clone https://github.com/melovagabond/azure_foundation.git
sudo chmod -R 777 ~/azure_foundation
cd ~/azure_foundation/docker || exit

# Create certificates directory and generate self-signed certificate
sudo mkdir -p certs
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./certs/server.key -out ./certs/server.crt -subj "/C=US/ST=Pennsylvania/L=Philadelphia/O=Daevonlab/OU=R&D/CN=localhost"
sudo chmod -R 777 ./certs

# Build and run the Docker container
sudo docker build -t webpage .
sudo docker run -d -p 443:443 --name webpage-container webpage