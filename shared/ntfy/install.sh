#!/usr/bin/env bash
set -euo pipefail

if ((EUID == 0)); then
  echo "Run this script as your desktop user; it will use sudo when needed." >&2
  exit 1
fi

for command in curl docker tailscale; do
  command -v "$command" >/dev/null || {
    echo "$command is required." >&2
    exit 1
  }
done

NTFY_BASE_URL="${NTFY_BASE_URL:?Set NTFY_BASE_URL to the tailnet HTTPS URL}"
NTFY_HTTPS_PORT="${NTFY_HTTPS_PORT:-2586}"
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ntfy"
URL_FILE="$CONFIG_DIR/pi-url"

if [[ ! "$NTFY_HTTPS_PORT" =~ ^[0-9]+$ ]] || ((NTFY_HTTPS_PORT < 1 || NTFY_HTTPS_PORT > 65535)); then
  echo "Invalid NTFY_HTTPS_PORT: $NTFY_HTTPS_PORT" >&2
  exit 1
fi

if [[ "$NTFY_BASE_URL" != https://* ]] || [[ "$NTFY_BASE_URL" =~ [[:space:]] ]]; then
  echo "NTFY_BASE_URL must be an HTTPS URL without spaces." >&2
  exit 1
fi
NTFY_BASE_URL="${NTFY_BASE_URL%/}"

if [[ -n "${NTFY_TOPIC:-}" ]]; then
  topic="$NTFY_TOPIC"
elif [[ -f "$URL_FILE" ]]; then
  topic="$(<"$URL_FILE")"
  topic="${topic##*/}"
else
  topic="$(uname -n)"
fi

if [[ ! "$topic" =~ ^[-_A-Za-z0-9]{1,64}$ ]]; then
  echo "Invalid ntfy topic: $topic" >&2
  exit 1
fi

endpoint="$NTFY_BASE_URL/$topic"

echo "==> Starting ntfy..."
NTFY_BASE_URL="$NTFY_BASE_URL" docker compose -f "$INSTALL_DIR/compose.yml" up -d

for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:2586/v1/health >/dev/null; then
    break
  fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:2586/v1/health >/dev/null

echo "==> Publishing ntfy through Tailscale Serve..."
sudo tailscale serve --bg --yes --https="$NTFY_HTTPS_PORT" http://127.0.0.1:2586
curl --fail --silent --retry 5 --retry-delay 1 "$NTFY_BASE_URL/v1/health" >/dev/null

mkdir -p "$CONFIG_DIR"
printf '%s\n' "$endpoint" >"$URL_FILE"
chmod 600 "$URL_FILE"

curl --fail --silent \
  -H "Title: ntfy is ready" \
  -H "Tags: white_check_mark" \
  -d "Installed on $(uname -n)" \
  "$endpoint" >/dev/null

echo
echo "==> ntfy is ready."
echo "    Server: $NTFY_BASE_URL"
echo "    Topic:  $topic"
echo "    Pi config: $URL_FILE"
echo "    Subscribe to this server and topic in the ntfy iOS app."
