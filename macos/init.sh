#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$DOTSYS_REPO_HOME/shared/brew/init.sh"
brew bundle --file="$DOTSYS_REPO_HOME"/shared/brew/Brewfile.default
brew bundle --file="$DOTSYS_REPO_HOME"/macos/Brewfile

"$DOTSYS_REPO_HOME/shared/mise/init.sh"
"$DOTSYS_REPO_HOME/shared/cargo/init.sh"
