#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Installing Sway..."

sudo pacman -S --needed --noconfirm \
  sway sway-contrib swaybg swayidle \
  xdg-desktop-portal-wlr xorg-xwayland \
  autotiling-rs \
  libpulse \
  rofi-wayland rofi-calc \
  flameshot \
  wev

# Includes the `swaylock` binary.
paru -S --needed --noconfirm swaylock-effects

# Fingerprint auth with swaylock.
# TODO: Yeah this isn't ideal. There's a best-practice way to do this instead.
# sudo cp "$DOTFILES_REPO_HOME/config/swaylock/pam-d.config" /etc/pam.d/swaylock

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

mkdir -p "$XDG_CONFIG_HOME/uwsm"

# Override the system sway.desktop only when the proprietary NVIDIA driver is
# loaded. Sway refuses to start on proprietary NVIDIA without --unsupported-gpu.
# On AMD/Intel-only machines, the stock system sway.desktop works as-is.
if lsmod | grep -q '^nvidia '; then
  mkdir -p "$XDG_DATA_HOME/wayland-sessions"
  cat >"$XDG_DATA_HOME/wayland-sessions/sway.desktop" <<'EOF'
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
Exec=sway --unsupported-gpu
Type=Application
DesktopNames=sway;wlroots
EOF
fi

printf '%s\n' 'sway.desktop' >"$XDG_CONFIG_HOME/uwsm/default-id"

mkdir -p "$HOME/Pictures"
cp -r "$DOTSYS_REPO_HOME/wallpapers" ~/Pictures/
