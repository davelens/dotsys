#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"
SCRIPT="$REPO_ROOT/arch/init.d/sway.sh"

test -f "$SCRIPT"

# Session override is conditional on NVIDIA driver presence.
grep -q 'lsmod.*nvidia' "$SCRIPT"
grep -q '\$XDG_DATA_HOME/wayland-sessions' "$SCRIPT"
grep -q 'Exec=sway --unsupported-gpu' "$SCRIPT"

# Default session ID is always written.
grep -q '\$XDG_CONFIG_HOME/uwsm/default-id' "$SCRIPT"
grep -q '^sway.desktop$' < <(sed -n '/default-id/,+2p' "$SCRIPT")
