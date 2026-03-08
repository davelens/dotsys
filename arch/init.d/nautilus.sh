#!/usr/bin/env bash
set -e

echo "==> Setting up Nautilus with gvfs backends..."

sudo pacman -S --needed --noconfirm \
  sushi \
  gst-plugins-base \
  gst-plugins-good \
  gst-libav \
  gvfs \
  gvfs-afc \
  gvfs-dnssd \
  gvfs-gphoto2 \
  gvfs-mtp \
  gvfs-nfs \
  gvfs-smb \
  gvfs-wsdd \
  xdg-user-dirs-gtk \
  xdg-desktop-portal-gtk \
  nautilus

# Dark mode for libadwaita apps (e.g. Nautilus).
# In a standalone WM (no gnome-settings-daemon), libadwaita reads the
# color-scheme preference via xdg-desktop-portal-gtk's Settings interface.
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Restart the portal so it picks up the newly installed GTK backend.
systemctl --user restart xdg-desktop-portal.service

echo "Nautilus installed with gvfs and dark mode support."
