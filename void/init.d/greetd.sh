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

# Do not disable agetty or enable greetd here: either action can terminate a
# bootstrap running from VT1. void/init.sh switches VT1 only after all session
# infrastructure is ready.
