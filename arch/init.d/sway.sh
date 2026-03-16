#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Installing Sway..."

sudo pacman -S --needed --noconfirm \
	sway sway-contrib swaybg swayidle \
	xdg-desktop-portal-wlr xorg-xwayland \
  autotiling-rs \
	libpulse \
	rofi-wayland rofi-calc \
	flameshot \
	wev

# Includes the `swaylock` binary.
paru -S --needed --noconfirm swaylock-effects

# Fingerprint auth with swaylock.
# TODO: Yeah this isn't ideal. There's a best-practice way to do this instead.
# sudo cp "$DOTFILES_REPO_HOME/config/swaylock/pam-d.config" /etc/pam.d/swaylock

mkdir -p "$HOME/Pictures"
cp -r "$DOTSYS_REPO_HOME/wallpapers" ~/Pictures/
