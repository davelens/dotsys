#!/usr/bin/env bash
set -e
source arch/helpers.sh

echo "==> Setting up Bluetooth..."

sudo pacman -S --needed --noconfirm bluez bluez-utils
sudo systemctl enable bluetooth.service
# Restart Bluetooth after suspend/hibernate to fix dropped connections.
sudo systemctl enable "$DOTSYS_REPO_HOME/arch/systemd/bluetooth-resume.service"
