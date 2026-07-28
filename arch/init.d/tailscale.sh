#!/usr/bin/env bash
set -euo pipefail

# Install Tailscale and expose a local HTTP service over tailnet-only HTTPS.
# Tailscale HTTPS certificates must first be enabled in the admin console.
#
# Defaults to Recollect's local development server:
#   https://<machine>.<tailnet>.ts.net:4010 -> http://127.0.0.1:4010
#
# When recollect-phx.service exists, a systemd drop-in binds Phoenix to
# loopback and configures its public URL. This lets Tailscale use the same
# port on the machine's tailnet addresses without a listener collision.
#
# Override the service or either side when needed:
#   TAILSCALE_PHOENIX_SERVICE=my-app.service \
#   TAILSCALE_HTTPS_PORT=8443 \
#   TAILSCALE_BACKEND_URL=http://127.0.0.1:4000 \
#     ./tailscale.sh

HTTPS_PORT="${TAILSCALE_HTTPS_PORT:-4010}"
BACKEND_URL="${TAILSCALE_BACKEND_URL:-http://127.0.0.1:4010}"
PHOENIX_SERVICE="${TAILSCALE_PHOENIX_SERVICE:-recollect-phx.service}"

if ((EUID == 0)); then
  echo "Run this script as your desktop user; it will use sudo when needed." >&2
  exit 1
fi

if [[ ! "$HTTPS_PORT" =~ ^[0-9]+$ ]] || ((HTTPS_PORT < 1 || HTTPS_PORT > 65535)); then
  echo "Invalid TAILSCALE_HTTPS_PORT: $HTTPS_PORT" >&2
  exit 1
fi

if [[ ! "$BACKEND_URL" =~ ^http://127\.0\.0\.1:[0-9]+(/.*)?$ ]]; then
  echo "TAILSCALE_BACKEND_URL must include a port on http://127.0.0.1, got: $BACKEND_URL" >&2
  exit 1
fi

if [[ ! "$PHOENIX_SERVICE" =~ ^[a-zA-Z0-9_.@-]+\.service$ ]]; then
  echo "Invalid TAILSCALE_PHOENIX_SERVICE: $PHOENIX_SERVICE" >&2
  exit 1
fi

backend_port="${BACKEND_URL#http://127.0.0.1:}"
backend_port="${backend_port%%/*}"

echo "==> Installing Tailscale..."
sudo pacman -S --needed --noconfirm tailscale

echo "==> Enabling and restarting tailscaled..."
sudo systemctl enable --now tailscaled.service
sudo systemctl restart tailscaled.service

if ! sudo tailscale status --json 2>/dev/null |
  grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"'; then
  echo "==> This machine is not connected to a tailnet."
  echo "    Follow the authentication URL printed by Tailscale."
  sudo tailscale up --operator="$USER"
fi

dns_name="$(
  sudo tailscale status --json |
    awk -F'"' '/"DNSName"[[:space:]]*:/ {print $4; exit}'
)"
dns_name="${dns_name%.}"

if [[ -z "$dns_name" ]]; then
  echo "Tailscale is running, but its MagicDNS name could not be determined." >&2
  exit 1
fi

if systemctl --user cat "$PHOENIX_SERVICE" >/dev/null 2>&1; then
  drop_in_dir="$HOME/.config/systemd/user/${PHOENIX_SERVICE}.d"

  echo "==> Configuring $PHOENIX_SERVICE for the Tailscale HTTPS proxy..."
  mkdir -p "$drop_in_dir"
  cat >"$drop_in_dir/tailscale-https.conf" <<EOF
[Service]
Environment=BIND_IP=127.0.0.1
Environment=PORT=$backend_port
Environment=PHX_HOST=$dns_name
Environment=PHX_SCHEME=https
Environment=PHX_PORT=$HTTPS_PORT
EOF

  systemctl --user daemon-reload
  systemctl --user restart "$PHOENIX_SERVICE"
else
  echo "==> $PHOENIX_SERVICE is not installed; skipping its HTTPS environment drop-in."
fi

if sudo ss -H -ltn "sport = :$HTTPS_PORT" 2>/dev/null |
  grep -Eq '(^|[[:space:]])(0\.0\.0\.0|\*|\[::\]):'; then
  echo "Cannot configure HTTPS on port $HTTPS_PORT: another service listens on all addresses." >&2
  echo "Choose another TAILSCALE_HTTPS_PORT or move that service to another port." >&2
  exit 1
fi

echo "==> Serving $BACKEND_URL over tailnet HTTPS on port $HTTPS_PORT..."
sudo tailscale serve --bg --https="$HTTPS_PORT" "$BACKEND_URL"

if [[ "$HTTPS_PORT" == "443" ]]; then
  public_url="https://${dns_name}/"
else
  public_url="https://${dns_name}:${HTTPS_PORT}/"
fi

echo
echo "==> Tailscale HTTPS is configured."
echo "    URL: $public_url"
echo "    Backend: $BACKEND_URL"
echo
echo "Current Serve configuration:"
sudo tailscale serve status
