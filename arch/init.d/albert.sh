#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --mflags --skipinteg: Skip integrity check (upstream checksum sometimes outdated)
paru -S --needed --noconfirm --mflags --skipinteg albert-bin
systemctl --user daemon-reload
systemctl --user enable "$SCRIPT_DIR/../systemd/albert.service"
systemctl --user restart albert

echo -e "Albert is ready!\n"
