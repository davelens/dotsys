#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"
SCRIPT="$REPO_ROOT/arch/bin/gpu-check"
TMPDIR="$(mktemp -d)"
FAKEBIN="$TMPDIR/bin"

cleanup() {
	rm -rf "$TMPDIR"
}

trap cleanup EXIT

mkdir -p "$TMPDIR/sys/class/drm/renderD128/device" \
	"$TMPDIR/sys/class/drm/renderD129/device/hwmon/hwmon6" \
	"$FAKEBIN"

cat >"$FAKEBIN/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '00000000:01:00.0, GeForce RTX 4080 SUPER, 37, 48, 1024, 16376'
EOF

chmod +x "$FAKEBIN/nvidia-smi"

cat >"$TMPDIR/sys/class/drm/renderD128/device/uevent" <<'EOF'
DRIVER=nouveau
PCI_CLASS=30000
PCI_ID=10DE:2702
PCI_SLOT_NAME=0000:01:00.0
EOF

cat >"$TMPDIR/sys/class/drm/renderD129/device/uevent" <<'EOF'
DRIVER=amdgpu
PCI_CLASS=30000
PCI_ID=1002:164E
PCI_SLOT_NAME=0000:16:00.0
EOF

printf '0\n' >"$TMPDIR/sys/class/drm/renderD129/device/gpu_busy_percent"
printf '%s\n' 20930560 >"$TMPDIR/sys/class/drm/renderD129/device/mem_info_vram_used"
printf '%s\n' 536870912 >"$TMPDIR/sys/class/drm/renderD129/device/mem_info_vram_total"
printf '44000\n' >"$TMPDIR/sys/class/drm/renderD129/device/hwmon/hwmon6/temp1_input"

OUTPUT="$(TERM=dumb PATH="$FAKEBIN:$PATH" GPU_CHECK_SYSFS_ROOT="$TMPDIR/sys" "$SCRIPT")"
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
printf '%s\n' "$OUTPUT" | grep -Eq 'GeForce RTX 4080 SUPER|AD103|10DE:2702'
printf '%s\n' "$OUTPUT" | grep -q 'Raphael'
printf '%s\n' "$OUTPUT" | grep -q 'dGPU'
printf '%s\n' "$OUTPUT" | grep -q 'iGPU'
printf '%s\n' "$OUTPUT" | grep -q '37%'
printf '%s\n' "$OUTPUT" | grep -q '48°'
printf '%s\n' "$OUTPUT" | grep -q '1.0 / 16 GiB'
printf '%s\n' "$OUTPUT" | grep -q '20 / 512 MiB'

# Temperature
printf '%s\n' "$OUTPUT" | grep -q '44°'

# Verdict
printf '%s\n' "$OUTPUT" | grep -q 'Verdict: GeForce RTX 4080 SUPER is dominant (37%)'
test "$STATUS" -eq 0
