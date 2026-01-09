#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Waybar..."

sudo pacman -S --needed --noconfirm waybar

# TODO: Add Mechabar as git submodule instead? https://github.com/Sejjy/MechaBar

# Run MechaBar's install script (makes scripts executable, installs dependencies)
"$XDG_CONFIG_HOME/waybar/install.sh"

# Enable and start the service
systemctl --user daemon-reload
systemctl --user enable "$SCRIPT_DIR/../systemd/waybar.service"
