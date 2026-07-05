#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Installing PipeWire..."

sudo xbps-install -Sy pipewire wireplumber

# Per the Void handbook: make the single pipewire process also spawn
# wireplumber and the pulse compatibility server.
sudo mkdir -p /etc/pipewire/pipewire.conf.d
sudo tee /etc/pipewire/pipewire.conf.d/10-exec.conf >/dev/null <<'EOF'
context.exec = [
    { path = "/usr/bin/wireplumber" args = "" }
    { path = "/usr/bin/pipewire" args = "-c pipewire-pulse.conf" }
]
EOF

# Run pipewire as a turnstile user service (needs the session bus from the
# envdir; starts once dbus is up).
mkdir -p "$HOME/.config/service/pipewire"
ln -sf "$DOTSYS_REPO_HOME/void/user-services/pipewire/run" \
  "$HOME/.config/service/pipewire/run"
