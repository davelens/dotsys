#!/usr/bin/env bash
set -e

VM_NAME="archlinux"
VM_RAM=16384
VM_CPUS=8
VM_DISK_SIZE=20
VM_DISK_DIR="$HOME/.local/share/images"
VM_DISK="$VM_DISK_DIR/$VM_NAME.qcow2"
ISO_URL="https://mirror.1ago.be/archlinux/iso/latest/archlinux-x86_64.iso"
ISO_DIR="$HOME/Downloads"
ISO_FILE="$ISO_DIR/archlinux-x86_64.iso"

echo "==> Setting up Arch Linux VM ($VM_NAME)..."

# Ensure libvirtd is running.
if ! systemctl is-active --quiet libvirtd; then
  echo "    Starting libvirtd..."
  sudo systemctl start libvirtd
fi

# Remove existing VM with the same name if it exists.
if virsh -c qemu:///session dominfo "$VM_NAME" &>/dev/null; then
  echo "    Removing existing VM '$VM_NAME'..."
  virsh -c qemu:///session destroy "$VM_NAME" 2>/dev/null || true
  virsh -c qemu:///session undefine "$VM_NAME" --nvram 2>/dev/null || true
fi

mkdir -p "$VM_DISK_DIR"

# Download the latest Arch ISO if not already present.
if [[ ! -f "$ISO_FILE" ]]; then
  echo "    Downloading Arch Linux ISO..."
  wget -q --show-progress -O "$ISO_FILE" "$ISO_URL"
else
  echo "    Using existing ISO: $ISO_FILE"
fi

# Create a fresh disk image.
if [[ -f "$VM_DISK" ]]; then
  echo "    Removing old disk image..."
  rm -f "$VM_DISK"
fi

echo "    Creating ${VM_DISK_SIZE}G disk image..."
qemu-img create -f qcow2 "$VM_DISK" "${VM_DISK_SIZE}G"

echo "    Creating VM with virt-install..."
virt-install \
  --name "$VM_NAME" \
  --ram "$VM_RAM" \
  --vcpus "$VM_CPUS" \
  --disk path="$VM_DISK",format=qcow2,bus=virtio \
  --cdrom "$ISO_FILE" \
  --os-variant archlinux \
  --boot uefi \
  --network user,model=virtio \
  --graphics spice,listen=none \
  --video virtio \
  --channel spicevmc \
  --sound default \
  --noautoconsole

echo ""
echo "VM '$VM_NAME' created. Open virt-manager to access the console."
echo "After installing Arch, you can remove the ISO with:"
echo "    rm $ISO_FILE"
