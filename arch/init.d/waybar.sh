#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Waybar..."

# bluetoothctl, nmcli, checkupdates,...
sudo pacman -S --needed --noconfirm waybar \
  bluez bluez-utils \
  brightnessctl \
  fzf \
  libpulse \
  networkmanager \
  pacman-contrib \
  pipewire-pulse \
  otf-commit-mono-nerd

systemctl --user daemon-reload
systemctl --user enable "$SCRIPT_DIR/../systemd/waybar.service"

pgrep waybar >/dev/null && pkill waybar
waybar &>/dev/null &
disown
