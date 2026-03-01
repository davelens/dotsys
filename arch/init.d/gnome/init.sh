#!/usr/bin/env bash
set -e
source arch/helpers.sh

echo "==> Installing GNOME packages..."
"$DOTSYS_REPO_HOME/arch/bin/pacman" --install-from-file "$DOTSYS_REPO_HOME/arch/packages/gnome.txt"

echo "==> Configuring GNOME settings..."
"$DOTSYS_REPO_HOME/arch/init.d/gnome/settings.sh"

echo "GNOME installation complete."
