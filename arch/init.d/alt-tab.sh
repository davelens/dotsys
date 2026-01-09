#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Alt+Tab window switcher for Sway (Gnome-style)
# https://github.com/lostatc/swtchr

echo "==> Configuring swtchr..."

sudo pacman -S --needed --noconfirm gtk4 gtk4-layer-shell
paru -S --needed --noconfirm swtchr
systemctl --user daemon-reload
systemctl --user enable "$SCRIPT_DIR/../systemd/swtchrd.service"
systemctl --user restart swtchrd
