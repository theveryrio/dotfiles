#!/bin/bash

# Script to install NVIDIA Container Toolkit (nvidia-docker2) on Ubuntu
# Requires NVIDIA driver and Docker to be pre-installed

set -e

echo "[1/6] Updating system packages"
sudo apt update -y && sudo apt upgrade -y

echo "[2/6] Checking if Docker is installed"
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker before running this script."
    exit 1
fi

echo "[3/6] Removing any existing NVIDIA Docker packages"
sudo apt remove -y nvidia-docker2 nvidia-container-toolkit libnvidia-container-tools libnvidia-container1 || true

echo "[4/6] Adding NVIDIA package repositories"
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)

# Add GPG key
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /etc/apt/keyrings/nvidia-container-toolkit.gpg

# Add repository list
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] https://#' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

echo "[5/6] Installing NVIDIA Container Toolkit"
sudo apt update
sudo apt install -y nvidia-docker2

echo "[6/6] Restarting Docker daemon"
sudo systemctl restart docker

echo
echo "To verify NVIDIA Docker is working, run:"
echo "  docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi"