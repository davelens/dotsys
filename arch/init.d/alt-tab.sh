#!/usr/bin/env bash
set -e
source arch/helpers.sh

# Alt+Tab window switcher for Sway (Gnome-style)
# https://github.com/lostatc/swtchr

echo "==> Configuring swtchr..."

sudo pacman -S --needed --noconfirm gtk4 gtk4-layer-shell
paru -S --needed --noconfirm swtchr
systemctl --user daemon-reload
systemctl --user enable "$DOTSYS_REPO_HOME/arch/systemd/swtchrd.service"
systemctl --user restart swtchrd
