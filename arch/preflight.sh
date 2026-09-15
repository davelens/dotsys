#!/usr/bin/env bash
set -e

install_paru() {
  command -v paru &>/dev/null && return
  sudo pacman -S --needed --noconfirm base-devel git
  local source="${XDG_CACHE_HOME:-$HOME/.cache}/dotsys/paru"
  mkdir -p "${source%/*}"
  if [[ -e $source || -L $source ]]; then
    echo 'Existing paru build directory preserved; review/remove it explicitly before retrying.' >&2
    return 1
  fi
  git clone https://aur.archlinux.org/paru.git "$source"
  (cd "$source" && makepkg -si --noconfirm)
  # Retain the reviewed build source; never delete an unrelated destination.
}

install_flatpak() {
  command -v flatpak &>/dev/null && return
  sudo pacman -S --needed --noconfirm flatpak
  flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

###############################################################################

main() {
  sudo pacman -Syu --noconfirm
  install_paru
  install_flatpak
}

if [[ ${1:-} == --aur ]]; then install_paru; else main "$@"; fi
