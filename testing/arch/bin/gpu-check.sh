#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"
SCRIPT="$REPO_ROOT/arch/bin/gpu-check"
TMPDIR="$(mktemp -d)"

cleanup() {
	rm -rf "$TMPDIR"
}

trap cleanup EXIT

mkdir -p "$TMPDIR/sys/class/drm/renderD128/device/hwmon/hwmon5" \
	"$TMPDIR/sys/class/drm/renderD129/device/hwmon/hwmon6"

cat >"$TMPDIR/sys/class/drm/renderD128/device/uevent" <<'EOF'
DRIVER=amdgpu
PCI_CLASS=30000
PCI_ID=1002:7480
PCI_SLOT_NAME=0000:c3:00.0
EOF

cat >"$TMPDIR/sys/class/drm/renderD129/device/uevent" <<'EOF'
DRIVER=amdgpu
PCI_CLASS=38000
PCI_ID=1002:150E
PCI_SLOT_NAME=0000:c4:00.0
EOF

printf '74\n' >"$TMPDIR/sys/class/drm/renderD128/device/gpu_busy_percent"
printf '%s\n' 1181116006 >"$TMPDIR/sys/class/drm/renderD128/device/mem_info_vram_used"
printf '61000\n' >"$TMPDIR/sys/class/drm/renderD128/device/hwmon/hwmon5/temp1_input"

printf '1\n' >"$TMPDIR/sys/class/drm/renderD129/device/gpu_busy_percent"
printf '%s\n' 427819008 >"$TMPDIR/sys/class/drm/renderD129/device/mem_info_vram_used"
printf '44000\n' >"$TMPDIR/sys/class/drm/renderD129/device/hwmon/hwmon6/temp1_input"

OUTPUT="$(TERM=dumb GPU_CHECK_SYSFS_ROOT="$TMPDIR/sys" "$SCRIPT")"
STATUS=$?

# Box structure
printf '%s\n' "$OUTPUT" | grep -q '╭'
printf '%s\n' "$OUTPUT" | grep -q '╰'
printf '%s\n' "$OUTPUT" | grep -q '│ GPU Check'

# Column headers
printf '%s\n' "$OUTPUT" | grep -q 'USE%'
printf '%s\n' "$OUTPUT" | grep -q 'TEMP'
printf '%s\n' "$OUTPUT" | grep -q 'VRAM'

# Data rows
printf '%s\n' "$OUTPUT" | grep -q '74%'
printf '%s\n' "$OUTPUT" | grep -q '1%'
printf '%s\n' "$OUTPUT" | grep -q '█'

# Temperature
printf '%s\n' "$OUTPUT" | grep -q '61°'
printf '%s\n' "$OUTPUT" | grep -q '44°'

# Verdict
printf '%s\n' "$OUTPUT" | grep -q 'Verdict: dGPU active and dominant'
test "$STATUS" -eq 0
