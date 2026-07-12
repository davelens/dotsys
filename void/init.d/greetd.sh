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

# Do not enable greetd here: linking the service immediately takes over VT1
# and can interrupt the bootstrap before turnstile configures the login session.
# void/init.sh enables it only after all session infrastructure is ready.
