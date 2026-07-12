#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

read_packages() {
  awk '!/^[[:space:]]*#/ && NF { print $1 }' "$1"
}

install_xbps_packages() {
  local file="$DOTSYS_REPO_HOME/void/packages/xbps.txt"
  local packages
  mapfile -t packages < <(read_packages "$file")

  if [[ ${#packages[@]} -gt 0 ]]; then
    echo "==> Installing Void packages..."
    sudo xbps-install -Sy "${packages[@]}"
  fi
}

install_flatpak_packages() {
  local file="$DOTSYS_REPO_HOME/void/packages/flatpak.txt"
  local packages
  mapfile -t packages < <(read_packages "$file")

  if [[ ${#packages[@]} -gt 0 ]]; then
    echo "==> Installing Flatpak applications..."
    flatpak --user install -y --noninteractive flathub "${packages[@]}"
  fi
}

install_xbps_packages
install_flatpak_packages
