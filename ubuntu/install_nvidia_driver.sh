#!/bin/bash

# Script to automatically install the latest recommended NVIDIA driver
# For Ubuntu/Debian-based systems

set -e

echo "[1/6] Updating system packages"
sudo apt update -y && sudo apt upgrade -y

echo "[2/6] Removing existing NVIDIA drivers (if any)"
sudo apt-get remove -y --purge '^nvidia-.*' || true

echo "[3/6] Installing required packages"
sudo apt install -y build-essential dkms linux-headers-$(uname -r) curl wget software-properties-common

echo "[4/6] Adding NVIDIA graphics-drivers PPA"
sudo add-apt-repository -y ppa:graphics-drivers/ppa
sudo apt update

echo "[5/6] Detecting latest recommended NVIDIA driver"
latest_driver=$(ubuntu-drivers devices | grep "recommended" | awk '{print $3}')

if [ -z "$latest_driver" ]; then
    echo "No recommended driver found."
    exit 1
fi

echo "Latest recommended driver: $latest_driver"

echo "[6/6] Installing NVIDIA driver"
sudo apt install -y "$latest_driver"

echo
echo "Installation complete. Please reboot your system."
echo "Run 'sudo reboot' to apply the changes."