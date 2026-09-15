#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

case ${1:-} in
  --bootstrap)
    sudo xbps-install -Sy bash python3 git coreutils sed tmux mise neovim delta gnupg base-devel curl tar unzip
    exit ;;
  --selected)
    [[ $# == 2 ]] || exit 1
    if [[ ,$2, == *,sway,* ]]; then "$DOTSYS_REPO_HOME/void/init.d/sway.sh" --packages; fi
    exit ;;
esac

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
