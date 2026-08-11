#!/usr/bin/env bash
set -euo pipefail
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ((EUID == 0)); then
  echo "Run this script as your desktop user; it will use sudo when needed." >&2
  exit 1
fi

running_kernel="$(uname -r)"
if [[ ! -d "/usr/lib/modules/$running_kernel" ]]; then
  echo "Kernel modules for $running_kernel are no longer installed; reboot before starting Docker containers." >&2
  exit 1
fi

sudo pacman -S --needed --noconfirm docker docker-compose

for service in docker tailscaled; do
  if ! systemctl cat "$service.service" >/dev/null 2>&1; then
    echo "$service.service is not installed." >&2
    exit 1
  fi
  sudo systemctl enable --now "$service.service"
done

if ! sudo tailscale status --json 2>/dev/null |
  grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"'; then
  echo "Tailscale is not connected. Run arch/init.d/tailscale.sh first." >&2
  exit 1
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

https_port="${NTFY_HTTPS_PORT:-2586}"
NTFY_BASE_URL="https://${dns_name}:${https_port}" \
NTFY_HTTPS_PORT="$https_port" \
  "$DOTSYS_REPO_HOME/shared/ntfy/install.sh"
