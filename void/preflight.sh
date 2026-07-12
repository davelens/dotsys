#!/usr/bin/env bash
set -e

echo
echo "==> Preflight: updating system + enabling extra repos..."

# Update xbps itself first, then the world.
sudo xbps-install -Syu xbps
sudo xbps-install -yu

# This personalized profile targets x86_64 glibc. Steam needs the nonfree
# and both multilib repositories.
if [[ "$(xbps-uhelper arch)" != "x86_64" ]]; then
  echo "error: the dotsys Void profile requires x86_64 glibc" >&2
  exit 1
fi
sudo xbps-install -Sy \
  void-repo-nonfree \
  void-repo-multilib \
  void-repo-multilib-nonfree \
  flatpak

# Keep desktop applications user-scoped, like the Arch bootstrap.
flatpak remote-add --user --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
