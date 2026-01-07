#!/usr/bin/env bash
set -e

echo "==> Installing Sway..."

sudo pacman -S --needed --noconfirm \
  sway sway-contrib swaybg swayidle swaylock \
  mako \
  libpulse \
  grim \
  rofi-wayland \
  wev

# Fingerprint auth with swaylock.
sudo cp "$DOTFILES_REPO_HOME/config/arch/swaylock/pam-d.config" /etc/pam.d/swaylock
