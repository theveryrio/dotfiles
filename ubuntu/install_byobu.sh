#!/bin/bash

# Script to install byobu on Ubuntu from the official PPA
# Enables byobu at login for the current user

set -e

echo "[1/4] Adding byobu PPA"
sudo apt update -y
sudo apt install -y software-properties-common   # provides add-apt-repository
sudo add-apt-repository -y ppa:byobu/ppa

echo "[2/4] Installing byobu"
sudo apt update -y
sudo apt install -y byobu

echo "[3/4] Enabling byobu at login"
byobu-enable

echo "[4/4] Verifying installation"
echo
echo "byobu version:"
byobu --version | head -1 || echo "byobu installation failed or not found in PATH."

echo
echo "byobu is enabled at login. Start it now with: 'byobu'"
