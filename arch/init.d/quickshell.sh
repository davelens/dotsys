#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Quickshell and dependencies..."

# Dependencies for various modules:
# - bluez, bluez-utils: Bluetooth support (bluetoothctl)
# - brightnessctl: Laptop backlight control
# - ddcutil: External monitor brightness via DDC/CI
# - networkmanager: WiFi management (nmcli)
# - pipewire, wireplumber: Audio (PipeWire integration)
# - otf-commit-mono-nerd: Nerd Font icons
# - libnotify: notify-send for test notifications
sudo pacman -S --needed --noconfirm \
  bluez bluez-utils \
  brightnessctl \
  ddcutil \
  networkmanager \
  pipewire wireplumber \
  otf-commit-mono-nerd \
  libnotify

# Quickshell from AUR (git version for latest features)
paru -S --needed --noconfirm quickshell-git

# Enable i2c for ddcutil (external monitor brightness)
# User needs to be in i2c group
if ! groups | grep -q i2c; then
  echo "==> Adding user to i2c group for ddcutil..."
  sudo usermod -aG i2c "$USER"
  echo "    Note: You may need to log out and back in for this to take effect."
fi

# Load i2c-dev module
if ! lsmod | grep -q i2c_dev; then
  echo "==> Loading i2c-dev kernel module..."
  sudo modprobe i2c-dev
fi

# Ensure i2c-dev loads on boot
if [[ ! -f /etc/modules-load.d/i2c-dev.conf ]]; then
  echo "==> Configuring i2c-dev to load on boot..."
  echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
fi

# Create systemd user service for quickshell
echo "==> Setting up Quickshell systemd service..."
systemctl --user daemon-reload
systemctl --user enable "$SCRIPT_DIR/../systemd/quickshell.service"
systemctl --user restart quickshell

# Install desktop entry for settings panel
echo "==> Installing settings panel desktop entry..."
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
cat >"${XDG_DATA_HOME:-$HOME/.local/share}/applications/quickshell-settings.desktop" <<'EOF'
[Desktop Entry]
Name=Settings
Comment=Open our shell settings panel
Exec=quickshell ipc call settings toggle
Icon=preferences-system
Type=Application
Categories=Settings;
EOF

# Stop mako if running (Quickshell has its own notification daemon)
if pgrep -x mako >/dev/null; then
  echo "==> Mako is running; you need to kill it before quickshell notifications are in use"
fi

echo "==> Starting Quickshell..."
pgrep -x quickshell >/dev/null && pkill quickshell
systemctl --user start quickshell.service

echo "==> Quickshell installation complete!"
echo ""
echo "NOTE: If using external monitors with brightness control, log out/in for i2c group to take effect"
