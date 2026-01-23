#!/usr/bin/env bash
set -e

# This installs the Arkenfox user.js file alongside its updater.
# Picks up on my user-overrides.js file and symlinks it into the profile dir
# before it runs the updater. This way it can pick up on it and append it to
# the generated user.js.

FIREFOX_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox"
PROFILES_INI="$FIREFOX_DIR/profiles.ini"

if [[ ! -f "$PROFILES_INI" ]]; then
  echo "Error: profiles.ini not found at $PROFILES_INI"
  echo "Make sure Firefox has been run at least once."
  exit 1
fi

# Find the default-release profile directory.
PROFILE_PATH=$(awk -F= '
  /^\[/ { section=$0 }
  /^Default=1/ { found=section }
  /^Path=/ && found { print $2; exit }
' "$PROFILES_INI")

if [[ -z "$PROFILE_PATH" ]]; then
  echo "Error: Could not find default profile in profiles.ini"
  exit 1
fi

PROFILE_DIR="$FIREFOX_DIR/$PROFILE_PATH"

if [[ ! -d "$PROFILE_DIR" ]]; then
  echo "Error: Profile directory not found: $PROFILE_DIR"
  exit 1
fi

echo "==> Installing arkenfox to $PROFILE_DIR..."

curl -sL -o "$PROFILE_DIR/user.js" \
  https://raw.githubusercontent.com/arkenfox/user.js/master/user.js

curl -sL -o "$PROFILE_DIR/updater.sh" \
  https://raw.githubusercontent.com/arkenfox/user.js/master/updater.sh

chmod +x "$PROFILE_DIR/updater.sh"

# Symlink user-overrides.js from dotfiles.
OVERRIDES_SRC="$DOTFILES_REPO_HOME/config/firefox/user-overrides.js"
OVERRIDES_DST="$PROFILE_DIR/user-overrides.js"

if [[ -z "$DOTFILES_REPO_HOME" ]]; then
  echo "Error: DOTFILES_REPO_HOME is not set"
  exit 1
fi

if [[ ! -f "$OVERRIDES_SRC" ]]; then
  echo "Error: user-overrides.js not found at $OVERRIDES_SRC"
  exit 1
fi

if [[ -L "$OVERRIDES_DST" ]]; then
  rm "$OVERRIDES_DST"
elif [[ -f "$OVERRIDES_DST" ]]; then
  echo "Warning: Backing up existing user-overrides.js to user-overrides.js.bak"
  mv "$OVERRIDES_DST" "$OVERRIDES_DST.bak"
fi

ln -s "$OVERRIDES_SRC" "$OVERRIDES_DST"
echo "==> Symlinked user-overrides.js"

echo "==> Running arkenfox updater..."
cd "$PROFILE_DIR"
./updater.sh -s

echo "==> Done. Arkenfox installed to $PROFILE_DIR"
