#!/usr/bin/env bash
set -e
source arch/helpers.sh

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
# TODO: Yeah this isn't ideal. There's a best-practice way to do this instead.
# sudo cp "$DOTFILES_REPO_HOME/config/swaylock/pam-d.config" /etc/pam.d/swaylock

mkdir -p "$HOME/Pictures"
cp -r "$DOTSYS_REPO_HOME/wallpapers" ~/Pictures/
