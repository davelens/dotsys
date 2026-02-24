#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing kanshi..."
sudo pacman -S --needed --noconfirm kanshi

echo "==> Setting up kanshi systemd service..."
systemctl --user daemon-reload
systemctl --user enable "$SCRIPT_DIR/../systemd/kanshi.service"
systemctl --user restart kanshi

echo "==> kanshi installation complete!"
