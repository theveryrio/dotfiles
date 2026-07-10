#!/bin/bash

# Script to install the latest Node.js LTS on Ubuntu from the official NodeSource repository
# Uses NodeSource's setup_lts.x, which always tracks the current Active LTS major
# Installs system-wide via apt so 'node' and 'npm' are on PATH for all users

set -e

echo "[1/4] Installing prerequisites (curl, ca-certificates)"
sudo apt update -y
sudo apt install -y ca-certificates curl

echo "[2/4] Adding NodeSource LTS repository"
# setup_lts.x resolves to the current LTS major and configures the apt repo + GPG key
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

echo "[3/4] Installing Node.js"
sudo apt install -y nodejs

echo "[4/4] Verifying installation"
echo
echo "Node.js version:"
node --version || echo "Node.js installation failed or not found in PATH."
echo "npm version:"
npm --version || echo "npm installation failed or not found in PATH."
