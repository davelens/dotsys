#!/usr/bin/env bash
set -e

echo "==> Setting up greetd + tuigreet..."

sudo pacman -S --needed --noconfirm greetd greetd-tuigreet

# Disable GDM if it's currently enabled.
if systemctl is-enabled gdm.service &>/dev/null; then
  echo "    Disabling gdm..."
  sudo systemctl disable gdm.service
fi

# Configure greetd to use tuigreet with Sway as the default session.
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-user-session --cmd sway-start"
user = "greeter"
EOF

sudo systemctl enable greetd.service
