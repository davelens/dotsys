#!/usr/bin/env bash
set -e

echo "==> Installing Sway..."

sudo pacman -S --needed --noconfirm \
  sway sway-contrib swaybg swayidle \
  mako \
  libpulse \
  grim \
  rofi-wayland rofi-calc \
  wev

# Includes the `swaylock` binary.
paru -S --needed --noconfirm swaylock-effects

# Fingerprint auth with swaylock.
sudo cp "$DOTFILES_REPO_HOME/config/arch/swaylock/pam-d.config" /etc/pam.d/swaylock

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HOME/Pictures"
cp -r "$SCRIPT_DIR/../../wallpapers" ~/Pictures/
