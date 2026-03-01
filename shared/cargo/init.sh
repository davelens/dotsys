#!/usr/bin/env bash
set -e
source arch/helpers.sh

main() {
  if ! command -v cargo &>/dev/null; then
    echo "Error: cargo is not available. Rust may not be installed correctly."
    exit 1
  fi

  local packages
  mapfile -t packages < <(read_packages "$DOTSYS_REPO_HOME/shared/cargo/packages")

  echo "==> Installing cargo packages..."
  for pkg in "${packages[@]}"; do
    echo "    Installing $pkg..."
    cargo install --locked "$pkg"
  done
  echo "==> Cargo packages installed successfully."
}

main "$@"
