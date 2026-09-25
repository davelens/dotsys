#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

usage() {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo
  echo "Installs Homebrew and processes the Brewfile bundles."
  echo
  echo "Options:"
  echo "  --skip-bundles  Only install Homebrew, skip bundle installation."
  echo "  -h, --help      Show this help message."
  exit 0
}

skip_bundles=false

while [[ $# -gt 0 ]]; do
  case "$1" in
  --skip-bundles)
    skip_bundles=true
    shift
    ;;
  -h | --help)
    usage
    ;;
  *)
    usage
    ;;
  esac
done

if command -v brew &>/dev/null; then
  echo "==> Homebrew is already installed, updating..."
  brew update
else
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # A fresh install isn't on $PATH yet in this shell.
  for brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [[ -x "$brew" ]] && eval "$("$brew" shellenv)" && break
  done
fi

[[ "$skip_bundles" == true ]] && exit 0

echo "==> Installing Brewfile bundles..."
brew bundle --file="$DOTSYS_REPO_HOME/shared/brew/Brewfile.default"

if [[ "$(uname)" == "Darwin" ]]; then
  brew bundle --file="$DOTSYS_REPO_HOME/macos/Brewfile"
fi
