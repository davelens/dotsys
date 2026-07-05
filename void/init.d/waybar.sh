#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Installing Waybar..."

# Package translations vs arch/init.d/waybar.sh:
#   waybar               -> Waybar (capitalized on Void)
#   pacman-contrib       -> (n/a; xbps has no checkupdates equivalent here)
#   pipewire-pulse       -> handled by init.d/pipewire.sh
#   otf-commit-mono-nerd -> not packaged; fetched from nerd-fonts releases below
sudo xbps-install -Sy Waybar \
  bluez \
  brightnessctl \
  fzf \
  mako grim \
  nerd-fonts-symbols-ttf \
  unzip

# bluetoothctl is useless without the daemon.
sudo ln -sf /etc/sv/bluetoothd /var/service/

# CommitMono Nerd Font from the official nerd-fonts release (AUR-only on Arch).
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/CommitMonoNerd"
if [ ! -d "$FONT_DIR" ]; then
  echo "==> Fetching CommitMono Nerd Font..."
  tmp="$(mktemp -d)"
  curl -fL -o "$tmp/CommitMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CommitMono.zip"
  mkdir -p "$FONT_DIR"
  unzip -o "$tmp/CommitMono.zip" -d "$FONT_DIR" >/dev/null
  rm -rf "$tmp"
  fc-cache -f "$FONT_DIR"
fi

# Waybar as a turnstile user service (replaces the systemd user unit).
mkdir -p "$HOME/.config/service/waybar"
ln -sf "$DOTSYS_REPO_HOME/void/user-services/waybar/run" \
  "$HOME/.config/service/waybar/run"
