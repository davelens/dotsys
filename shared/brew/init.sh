#!/usr/bin/env bash
# Bootstrap is compatible with Apple's stock Bash; no dotfiles shell needed.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
skip=false confirm=true
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-bundles) skip=true ;;
    --no-confirm) confirm=false ;;
    -h|--help)
      echo 'Usage: shared/brew/init.sh [--skip-bundles] [--no-confirm]'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done
export PATH="/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"
if ! command -v brew >/dev/null; then
  [[ ${HOME:-} == /* ]] || { echo 'Set an absolute HOME.' >&2; exit 1; }
  cache=${XDG_CACHE_HOME:-$HOME/.cache}/dotsys
  mkdir -p "$cache"
  installer=$(mktemp "$cache/homebrew.XXXXXX")
  trap 'rm -f "$installer"' EXIT
  # The existing official Homebrew/install origin; download errors stop execution.
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
  NONINTERACTIVE=1 /bin/bash "$installer"
fi
$skip && exit 0
if $confirm; then
  [[ -t 0 ]] || { echo 'Brew bundles skipped; request --no-confirm explicitly.'; exit 0; }
  read -r -p 'Install the full personal Brew bundles? [y/N] ' answer
  [[ $answer == y ]] || exit 0
fi
brew bundle --file="$root/shared/brew/Brewfile.default"
if [[ $(uname -s) == Darwin ]]; then brew bundle --file="$root/macos/Brewfile"; fi
