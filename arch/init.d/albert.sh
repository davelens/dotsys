#!/usr/bin/env bash
set -e

# --mflags --skipinteg: Skip integrity check (upstream checksum sometimes outdated)
paru -S --needed --noconfirm --mflags --skipinteg albert-bin
systemctl --user daemon-reload
systemctl --user enable "$DOTSYS_REPO_HOME/arch/systemd/albert.service"
systemctl --user restart albert

echo -e "Albert is ready!\n"
