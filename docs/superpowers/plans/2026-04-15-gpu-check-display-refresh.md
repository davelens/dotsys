# GPU Check Display Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh `arch/bin/gpu-check` with `duf`-like boxed output, busy progress bars, and TTY-aware colors while preserving existing GPU detection and exit codes.

**Architecture:** Extend the existing Bash utility in place. Add one fake-sysfs shell test that asserts boxed output and progress bar behavior without depending on live GPU state, then update the formatter to render Unicode box characters, fixed-width busy bars, and colorized TTY output.

**Tech Stack:** Bash, Linux sysfs (`/sys/class/drm`), `shellcheck`

---

### Task 1: Add failing display regression test

**Files:**
- Create: `testing/arch/bin/gpu-check.sh`
- Test: `testing/arch/bin/gpu-check.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"
SCRIPT="$REPO_ROOT/arch/bin/gpu-check"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/sys/class/drm/renderD128/device" "$TMPDIR/sys/class/drm/renderD129/device"

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
printf '1\n' >"$TMPDIR/sys/class/drm/renderD129/device/gpu_busy_percent"
printf '%s\n' 427819008 >"$TMPDIR/sys/class/drm/renderD129/device/mem_info_vram_used"

OUTPUT="$(TERM=dumb GPU_CHECK_SYSFS_ROOT="$TMPDIR/sys" "$SCRIPT")"
STATUS=$?

printf '%s\n' "$OUTPUT" | grep -q '╭'
printf '%s\n' "$OUTPUT" | grep -q '│ GPU Check'
printf '%s\n' "$OUTPUT" | grep -q 'BUSY'
printf '%s\n' "$OUTPUT" | grep -q '74%'
printf '%s\n' "$OUTPUT" | grep -q '1%'
printf '%s\n' "$OUTPUT" | grep -q '█'
printf '%s\n' "$OUTPUT" | grep -q 'Verdict: dGPU active and dominant'
test "$STATUS" -eq 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash testing/arch/bin/gpu-check.sh`
Expected: FAIL because current script prints plain table output and does not include boxed layout markers.

- [ ] **Step 3: Write minimal implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Keep GPU detection logic. Replace plain row formatter with:
# - Unicode box renderer
# - fixed-width busy bar renderer
# - TTY-only ANSI color helpers
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash testing/arch/bin/gpu-check.sh`
Expected: PASS with no output.

- [ ] **Step 5: Run syntax and lint verification**

Run: `bash -n arch/bin/gpu-check && shellcheck arch/bin/gpu-check testing/arch/bin/gpu-check.sh`
Expected: no output.

### Task 2: Verify live display output and exit code

**Files:**
- Modify: `arch/bin/gpu-check`

- [ ] **Step 1: Run utility on live host**

Run: `arch/bin/gpu-check`
Expected: boxed Unicode report with busy bars and verdict.

- [ ] **Step 2: Verify non-TTY plain output path**

Run: `arch/bin/gpu-check | sed -n '1,20p'`
Expected: same box and bars, but without ANSI escape sequences.

- [ ] **Step 3: Verify exit code**

Run: `arch/bin/gpu-check >/tmp/gpu-check.out; status=$?; cat /tmp/gpu-check.out; printf '\nEXIT=%s\n' "$status"`
Expected: exit `0` when dGPU is dominant on current host.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-04-15-gpu-check-display-refresh-design.md docs/superpowers/plans/2026-04-15-gpu-check-display-refresh.md testing/arch/bin/gpu-check.sh arch/bin/gpu-check
git commit -m "arch/bin: refresh `gpu-check` with duf-style display"
```
