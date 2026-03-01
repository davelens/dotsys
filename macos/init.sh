#!/usr/bin/env bash
set -e
source arch/helpers.sh

"$DOTSYS_REPO_HOME/shared/brew/init.sh"
brew bundle --file="$DOTSYS_REPO_HOME"/shared/brew/Brewfile.default
brew bundle --file="$DOTSYS_REPO_HOME"/macos/Brewfile

"$DOTSYS_REPO_HOME/shared/mise/init.sh"
"$DOTSYS_REPO_HOME/shared/cargo/init.sh"
