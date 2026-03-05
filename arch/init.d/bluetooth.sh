#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Setting up Bluetooth..."

sudo pacman -S --needed --noconfirm bluez bluez-utils
sudo systemctl enable bluetooth.service
# Restart Bluetooth after suspend/hibernate to fix dropped connections.
sudo systemctl enable "$DOTSYS_REPO_HOME/arch/systemd/bluetooth-resume.service"
