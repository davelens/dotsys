#!/usr/bin/env bash
set -e

echo "==> Configuring fingerprint module..."

sudo pacman -S --needed --noconfirm fprintd

if fprintd-list "$USER" 2>/dev/null | grep -q "finger"; then
  echo "Fingerprints already enrolled, skipping enrollment"
else
  echo "Starting fingerprint enrollment..."
  fprintd-enroll
fi

# Add fingerprint auth to PAM files by inserting pam_fprintd.so before
# the existing pam_unix.so auth line, preserving the rest of the config.
for file in login su sudo; do
  pam_file="/etc/pam.d/$file"
  if grep -q "pam_fprintd.so" "$pam_file" 2>/dev/null; then
    echo "$pam_file already configured, skipping"
  elif grep -q "pam_unix.so" "$pam_file" 2>/dev/null; then
    sudo sed -i '/^auth.*pam_unix.so/i auth      sufficient pam_fprintd.so' "$pam_file"
    echo "Configured $pam_file"
  else
    echo "WARNING: $pam_file has no pam_unix.so line, skipping"
  fi
done
