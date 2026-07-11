#!/usr/bin/env bash
set -e

echo "==> Setting up greetd + tuigreet..."

sudo xbps-install -Sy greetd tuigreet

# Void's greetd system user is _greeter (not 'greeter' as on Arch).
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd sway-session"
user = "_greeter"
EOF

# tuigreet stores its --remember cache here.
sudo mkdir -p /var/cache/tuigreet
sudo chown _greeter:_greeter /var/cache/tuigreet

# greetd and agetty cannot both read from VT1. Void enables agetty-tty1 by
# default, so remove it from the active runsvdir before starting greetd.
if [ -e /var/service/agetty-tty1 ] || [ -L /var/service/agetty-tty1 ]; then
  echo "==> Disabling agetty on VT1..."
  sudo rm -f /var/service/agetty-tty1
fi

# runit: linking a service starts it within seconds. greetd claims VT1, so
# don't run this from the VT1 console; ssh or another VT is fine.
if [ ! -L /var/service/greetd ]; then
  echo "==> Enabling greetd (takes over VT1 immediately!)"
  sudo ln -s /etc/sv/greetd /var/service/
fi
