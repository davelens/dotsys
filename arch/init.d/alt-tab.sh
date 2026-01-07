#!/usr/bin/env bash
set -e

# Alt+Tab window switcher for Sway (Gnome-style)
# https://github.com/lostatc/swtchr

echo "==> Configuring swtchr..."

ln -sf "$DOTSYS_REPO_HOME/arch/systemd/swtchrd.service" \
  "$XDG_CONFIG_HOME/systemd/user/"

sudo pacman -S --needed --noconfirm gtk4 gtk4-layer-shell
paru -S --needed --noconfirm swtchr
systemctl --user daemon-reload
systemctl --user enable --now swtchrd
