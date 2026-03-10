#!/usr/bin/env bash
set -e

echo "==> Configuring dual boot with Windows..."

sudo pacman -S --needed --noconfirm ntfs-3g

# Enable os-prober so GRUB detects Windows.
if grep -q '^#\?GRUB_DISABLE_OS_PROBER' /etc/default/grub; then
	sudo sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
else
	echo 'GRUB_DISABLE_OS_PROBER=false' | sudo tee -a /etc/default/grub >/dev/null
fi

sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "Dual boot configured. Windows should now appear in the GRUB menu."
