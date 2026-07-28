#!/usr/bin/env bash
set -euo pipefail

# Install Tailscale and connect this machine to its tailnet.
#
# HTTPS certificates must be enabled once in the Tailscale admin console.
# Applications remain responsible for their own bind addresses and optional
# `tailscale serve` routes; this machine-level setup does not assume any app,
# service, or port.

if ((EUID == 0)); then
  echo "Run this script as your desktop user; it will use sudo when needed." >&2
  exit 1
fi

echo "==> Installing Tailscale..."
sudo pacman -S --needed --noconfirm tailscale

echo "==> Enabling and restarting tailscaled..."
sudo systemctl enable --now tailscaled.service
sudo systemctl restart tailscaled.service

# Give tailscaled a moment to restore its persisted login after a restart.
for _ in {1..20}; do
  if sudo tailscale status --json 2>/dev/null |
    grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"'; then
    break
  fi

  sleep 0.5
done

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

echo
echo "==> Tailscale is ready."
echo "    MagicDNS name: $dns_name"
echo "    HTTPS certificates: managed through the Tailscale admin setting"
echo
echo "Applications can opt into tailnet HTTPS independently, for example:"
echo "    sudo tailscale serve --bg --https=<https-port> http://127.0.0.1:<app-port>"
echo
echo "Current application-specific Serve routes (not managed by this script):"
sudo tailscale serve status
