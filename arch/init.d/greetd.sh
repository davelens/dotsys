#!/usr/bin/env bash
set -e

echo "==> Setting up greetd + tuigreet..."

sudo pacman -S --needed --noconfirm greetd greetd-tuigreet

# Configure greetd to use tuigreet with Sway as the default session.
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-user-session --cmd sway"
user = "greeter"
EOF

sudo systemctl enable greetd.service
