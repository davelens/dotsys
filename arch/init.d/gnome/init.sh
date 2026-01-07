#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing GNOME packages..."
utility arch pacman --install-from-file "$SCRIPT_DIR/../../packages/gnome.txt"

echo "==> Configuring GNOME settings..."
"$SCRIPT_DIR/settings.sh"

echo "GNOME installation complete."
