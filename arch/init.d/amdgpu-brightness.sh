#!/usr/bin/env bash
set -euo pipefail

product_name_file="${DOTSYS_PRODUCT_NAME_FILE:-/sys/class/dmi/id/product_name}"
grub_defaults="${DOTSYS_GRUB_DEFAULTS:-/etc/default/grub}"
grub_config="${DOTSYS_GRUB_CONFIG:-/boot/grub/grub.cfg}"

[[ -r $product_name_file ]] || exit 0
[[ $(<"$product_name_file") == "Laptop 16 (AMD Ryzen AI 300 Series)" ]] || exit 0

current="$(grep -oE 'amdgpu\.dcdebugmask=0x[[:xdigit:]]+' "$grub_defaults" | head -n 1 || true)"
if [[ -n $current ]]; then
  printf -v mask '0x%x' "$(( ${current#*=} | 0x40000 ))"
  sudo sed -i -E "s/amdgpu\.dcdebugmask=0x[[:xdigit:]]+/amdgpu.dcdebugmask=$mask/" "$grub_defaults"
else
  sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*)"$/\1 amdgpu.dcdebugmask=0x40000"/' "$grub_defaults"
fi

sudo grub-mkconfig -o "$grub_config"
