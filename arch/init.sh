#!/usr/bin/env bash
set -e

DOTSYS_REPO_HOME="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
export DOTSYS_REPO_HOME

mkdir -p "$XDG_CONFIG_HOME/systemd/user"

sudo ln -sf "$DOTSYS_REPO_HOME/arch/systemd/bluetooth-resume.service" /etc/systemd/system/
sudo systemctl enable bluetooth-resume.service
# Configure NetworkManager to use iwd as the WiFi backend.
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/wifi-backend.conf >/dev/null <<'EOF'
[device]
wifi.backend=iwd
EOF
sudo systemctl enable NetworkManager.service
sudo systemctl enable iwd.service

"$DOTSYS_REPO_HOME/arch/preflight.sh"
"$DOTSYS_REPO_HOME/shared/gnupg/init.sh"
"$DOTSYS_REPO_HOME/shared/mise/init.sh"
"$DOTSYS_REPO_HOME/shared/cargo/init.sh"
"$DOTSYS_REPO_HOME/arch/packages/init.sh" --update
"$DOTSYS_REPO_HOME/arch/init.d/greetd.sh"
"$DOTSYS_REPO_HOME/arch/init.d/sway.sh"
"$DOTSYS_REPO_HOME/arch/init.d/waybar.sh"
"$DOTSYS_REPO_HOME/arch/init.d/alt-tab.sh"
"$DOTSYS_REPO_HOME/arch/init.d/kanata.sh"
"$DOTSYS_REPO_HOME/arch/init.d/mariadb.sh"
"$DOTSYS_REPO_HOME/arch/init.d/power-profiles.sh"
# "$DOTSYS_REPO_HOME/shared/postgres/init.sh"
# NOTE: This is disabled for now until I can properly "reset" this to
# the default state of things. It should by-and-large work though.
# "$DOTSYS_REPO_HOME/arch/init.d/fingerprint-auth.sh"
