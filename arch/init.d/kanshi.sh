#!/usr/bin/env bash
set -e
source arch/helpers.sh

echo "==> Installing kanshi..."
sudo pacman -S --needed --noconfirm kanshi

echo "==> Setting up kanshi systemd service..."
systemctl --user daemon-reload
systemctl --user enable "$DOTSYS_REPO_HOME/arch/systemd/kanshi.service"
systemctl --user restart kanshi

echo "==> kanshi installation complete!"
