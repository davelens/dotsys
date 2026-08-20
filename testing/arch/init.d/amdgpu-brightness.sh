#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"
script="$repo_root/arch/init.d/amdgpu-brightness.sh"
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

mkdir -p "$sandbox/bin"
printf '%s\n' 'Laptop 16 (AMD Ryzen AI 300 Series)' >"$sandbox/product_name"
printf '%s\n' 'GRUB_CMDLINE_LINUX_DEFAULT="quiet amdgpu.dcdebugmask=0x1000"' >"$sandbox/grub"

cat >"$sandbox/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
cat >"$sandbox/bin/grub-mkconfig" <<'EOF'
#!/usr/bin/env bash
printf 'generated\n' >"$2"
EOF
chmod +x "$sandbox/bin/sudo" "$sandbox/bin/grub-mkconfig"

PATH="$sandbox/bin:$PATH" \
DOTSYS_PRODUCT_NAME_FILE="$sandbox/product_name" \
DOTSYS_GRUB_DEFAULTS="$sandbox/grub" \
DOTSYS_GRUB_CONFIG="$sandbox/grub.cfg" \
  "$script"

grep -q 'amdgpu.dcdebugmask=0x41000' "$sandbox/grub"
[[ $(grep -o 'amdgpu.dcdebugmask=' "$sandbox/grub" | wc -l) == 1 ]]
[[ -s $sandbox/grub.cfg ]]
