#!/bin/bash

# Script to install the latest Node.js LTS on macOS via Homebrew
# Detects the current LTS major from the official Node.js release index and
# installs the matching node@<major> formula

set -e

echo "[1/4] Checking Homebrew"
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Install it first with macos/install_homebrew.sh" >&2
    exit 1
fi

echo "[2/4] Detecting latest Node.js LTS major"
# nodejs.org/dist/index.json lists releases newest-first; entries with a string
# "lts" field (not false) are LTS releases, so the first match is the current LTS.
LTS_MAJOR=$(curl -fsSL https://nodejs.org/dist/index.json \
  | tr '}' '\n' \
  | grep '"lts":"' \
  | head -1 \
  | sed -E 's/.*"version":"v([0-9]+)\..*/\1/')
if [ -z "$LTS_MAJOR" ]; then
  echo "Could not determine the latest Node.js LTS version." >&2
  exit 1
fi
echo "      LTS major: $LTS_MAJOR"

echo "[3/4] Installing Node.js via Homebrew"
brew install "node@${LTS_MAJOR}"
# node@<major> is keg-only; force-link so 'node' and 'npm' land on PATH
brew link --overwrite --force "node@${LTS_MAJOR}"

echo "[4/4] Verifying installation"
echo
echo "Node.js version:"
node --version || echo "Node.js installation failed or not found in PATH."
echo "npm version:"
npm --version || echo "npm installation failed or not found in PATH."
