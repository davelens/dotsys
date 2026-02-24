#!/usr/bin/env bash
set -e

echo "==> Setting up Nautilus with gvfs backends..."

sudo pacman -S --needed --noconfirm \
  sushi \
  gvfs \
  gvfs-afc \
  gvfs-dnssd \
  gvfs-gphoto2 \
  gvfs-mtp \
  gvfs-nfs \
  gvfs-smb \
  gvfs-wsdd \
  nautilus

echo "Nautilus installed with gvfs support."
