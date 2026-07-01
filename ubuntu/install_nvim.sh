#!/bin/bash

# Script to install the latest version of Neovim on Ubuntu from the official prebuilt tarball
# Uses the neovim-releases build (glibc 2.17) for broad compatibility with older systems
# Installs into /opt and links vi/vim/nvim -> nvim in /usr/local/bin
#
# Installs the latest release by default; pin one with: NVIM_VERSION=v0.10.0 ./install_nvim.sh

set -e

NVIM_VERSION="${NVIM_VERSION:-latest}"

echo "[1/6] Installing prerequisites (curl, tar, ca-certificates)"
sudo apt update -y
sudo apt install -y ca-certificates curl tar

echo "[2/6] Detecting architecture"
case "$(uname -m)" in
  x86_64 | amd64) NVIM_ARCH="x86_64" ;;
  aarch64 | arm64) NVIM_ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
echo "      arch: $NVIM_ARCH, version: $NVIM_VERSION"

echo "[3/6] Downloading Neovim tarball"
# 'latest' uses GitHub's latest-release redirect; otherwise download the pinned tag.
if [ "$NVIM_VERSION" = "latest" ]; then
  NVIM_URL="https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz"
else
  NVIM_URL="https://github.com/neovim/neovim-releases/releases/download/${NVIM_VERSION}/nvim-linux-${NVIM_ARCH}.tar.gz"
fi
TMP_TARBALL="$(mktemp --suffix=.tar.gz)"
trap 'rm -f "$TMP_TARBALL"' EXIT
curl -fsSL -o "$TMP_TARBALL" "$NVIM_URL"

echo "[4/6] Extracting to /opt"
NVIM_DIR="/opt/nvim-linux-${NVIM_ARCH}"
sudo rm -rf "$NVIM_DIR"          # clean any previous install so re-runs are idempotent
sudo tar -C /opt -xzf "$TMP_TARBALL"

echo "[5/6] Linking vi/vim/nvim -> nvim"
for cmd in nvim vim vi; do
  sudo ln -sf "$NVIM_DIR/bin/nvim" "/usr/local/bin/$cmd"
done

echo "[6/6] Verifying installation"
echo
echo "Neovim version:"
nvim --version | head -1 || echo "Neovim installation failed or not found in PATH."
