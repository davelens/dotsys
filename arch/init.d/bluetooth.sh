#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Setting up Bluetooth..."

sudo pacman -S --needed --noconfirm bluez bluez-utils
sudo systemctl enable bluetooth.service
# Restart Bluetooth after suspend/hibernate to fix dropped connections.
sudo systemctl enable "$SCRIPT_DIR/../systemd/bluetooth-resume.service"
