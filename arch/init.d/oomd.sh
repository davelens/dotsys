#!/usr/bin/env bash
set -euo pipefail

# Kill the most memory-starved unit in the user session (e.g. one tmux pane)
# before the system thrashes into a lockup. The kernel OOM killer rarely fires
# in time when zram swap and page cache absorb the pressure.

echo "==> Configuring systemd-oomd..."

sudo mkdir -p /etc/systemd/system/user@.service.d
sudo tee /etc/systemd/system/user@.service.d/oomd.conf >/dev/null <<'EOF'
[Service]
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=60%
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now systemd-oomd.service

echo "systemd-oomd enabled. Check monitored cgroups with: oomctl"
