#!/usr/bin/env bash
set -e

echo "==> Setting up WiFi (iwd + NetworkManager)..."

sudo pacman -S --needed --noconfirm iwd networkmanager

# Configure iwd to defer connection management to NetworkManager.
sudo mkdir -p /etc/iwd
sudo tee /etc/iwd/main.conf >/dev/null <<'EOF'
[General]
EnableNetworkConfiguration=false

[Network]
NameResolvingService=systemd
EOF

# Configure NetworkManager to use iwd as the WiFi backend.
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/wifi-backend.conf >/dev/null <<'EOF'
[device]
wifi.backend=iwd
EOF

sudo systemctl enable NetworkManager.service
sudo systemctl enable iwd.service

echo "WiFi configured. Connect to a network with: nmcli device wifi connect <SSID> --ask"
