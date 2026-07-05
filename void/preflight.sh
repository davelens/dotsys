#!/usr/bin/env bash
set -e

echo "==> Preflight: updating system + enabling extra repos..."

# Update xbps itself first, then the world.
sudo xbps-install -Syu xbps
sudo xbps-install -yu

# Nonfree repo (intel-ucode, etc.) and flatpak, mirroring arch/preflight.sh.
sudo xbps-install -Sy void-repo-nonfree flatpak
flatpak remote-add --user --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
