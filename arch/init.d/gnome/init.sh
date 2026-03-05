#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../../ && pwd)"

echo "==> Installing GNOME packages..."
"$DOTSYS_REPO_HOME/arch/bin/pacman" --install-from-file "$DOTSYS_REPO_HOME/arch/packages/gnome.txt"

echo "==> Configuring GNOME settings..."
"$DOTSYS_REPO_HOME/arch/init.d/gnome/settings.sh"

echo "GNOME installation complete."
