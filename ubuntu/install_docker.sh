#!/bin/bash

# Script to install the latest version of Docker on Ubuntu
# Includes full cleanup of previous Docker data and sets up non-sudo usage in the current session

set -e

echo "[1/9] Updating system packages"
sudo apt update -y && sudo apt upgrade -y

echo "[2/9] Stopping Docker services if running"
sudo systemctl stop docker || true
sudo systemctl stop containerd || true

echo "[3/9] Removing old Docker packages"
sudo apt remove -y --purge docker docker-engine docker.io containerd runc || true

echo "[4/9] Deleting all Docker data (images, containers, volumes)"
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

echo "[5/9] Installing required packages"
sudo apt install -y ca-certificates curl gnupg lsb-release

echo "[6/9] Adding Docker’s official GPG key"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "[7/9] Setting up Docker repository"
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[8/9] Installing Docker Engine and CLI"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[9/9] Configuring non-root Docker usage"

# Ensure 'docker' group exists
getent group docker || sudo groupadd docker

# Add current user to the 'docker' group
sudo usermod -aG docker $USER

# Immediately apply new group in this session
exec sg docker newgrp `id -gn`

echo
echo "Docker version:"
docker version || echo "Docker installation failed or not found in PATH."

echo
echo "To verify Docker is working, run: 'docker run hello-world'"