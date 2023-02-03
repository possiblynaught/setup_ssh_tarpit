#!/bin/bash

# Debug
#set -x
set -Eeo pipefail

# Get script dir
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# Port for endlessh to target
PORT="22"
# Binary installation directory
BINARY_DIR="/usr/local/bin"
# Config dir
CONFIG_DIR="/etc/endlessh"
CONFIG_FILE="$CONFIG_DIR/config"
# Where to download and build endlessh files for installation
BUILD_DIR="$HOME/Documents/endlessh"

# Links
ENDLESS_GIT="https://github.com/skeeto/endlessh.git"
ENDLESS_ZIP="https://github.com/skeeto/endlessh/archive/refs/heads/master.zip"

# Clear out old downloaded files
rm -rf "$BUILD_DIR"

# Check for git and/or unzip
if command -v git &> /dev/null; then
  # Clone git repo
  git clone "$ENDLESS_GIT" "$BUILD_DIR"
elif command -v unzip &> /dev/null; then
  # Download and unzip
  wget "$ENDLESS_ZIP" -O /tmp/endless.zip
  uzip /tmp/endless.zip
  rm -f /tmp/endless.zip
  mv /tmp/endlessh-master "$BUILD_DIR"
else
  echo "Error, please install git or unzip and restart this script."
  exit 1
fi

# Build binary and install it
if ! command -v make &> /dev/null; then
  echo "Error, 'make' is required, please install 'build-essential' to correct this."
  exit 1
fi
cd "$BUILD_DIR" || exit 1
make
sudo mv endlessh "$BINARY_DIR/endlessh"
sudo cp util/endlessh.service /etc/systemd/system/

# Config endlessh
sudo mkdir -p "$CONFIG_DIR"
echo "Port $PORT
Delay 10000
MaxLineLength 32
MaxClients 4096
LogLevel 1
BindFamily 0" | sudo tee "$CONFIG_FILE"
# Enable lower ports (22)
SERVICE_CONFIG="/etc/systemd/system/endlessh.service"
sudo sed -i 's/\#AmbientCapabilities/AmbientCapabilities/g' "$SERVICE_CONFIG"
sudo sed -i 's/PrivateUsers/\#PrivateUsers/g' "$SERVICE_CONFIG"
sudo setcap 'cap_net_bind_service=+ep' "$BINARY_DIR/endlessh"
# Start service
sudo systemctl enable endlessh
sudo systemctl start endlessh
sleep 3

# Notify complete
echo "
Complete, endlessh has been installed at $(which endlessh) and enabled on port: $PORT
Version:"
endlessh -v
systemctl status endlessh
