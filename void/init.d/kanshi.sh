#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Installing kanshi..."
sudo xbps-install -Sy kanshi

# kanshi as a turnstile user service (replaces the systemd user unit).
mkdir -p "$HOME/.config/service/kanshi"
ln -sf "$DOTSYS_REPO_HOME/void/user-services/kanshi/run" \
  "$HOME/.config/service/kanshi/run"

echo "==> kanshi installation complete!"
