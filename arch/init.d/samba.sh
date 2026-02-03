#!/usr/bin/env bash
set -e

# Synology NAS connection details
NAS_HOST="${NAS_HOST:-192.168.0.184}"
NAS_HOSTNAME="alexandria.local"
CREDENTIALS_FILE="/etc/samba/credentials"
MOUNT_BASE="/mnt/alexandria"

# Shares to mount
SHARES=(storage movies tv-shows)

echo "==> Installing Samba client packages..."
sudo pacman -S --needed --noconfirm cifs-utils

echo "==> Creating mount directories..."
for share in "${SHARES[@]}"; do
	sudo mkdir -p "${MOUNT_BASE}/${share}"
done

echo "==> Checking credentials file..."
if [[ ! -f "$CREDENTIALS_FILE" ]]; then
	echo "Error: Credentials file not found at $CREDENTIALS_FILE"
	echo "Create it with:"
	echo "  sudo tee $CREDENTIALS_FILE <<EOF"
	echo "  username=your_nas_user"
	echo "  password=your_nas_password"
	echo "  EOF"
	echo "  sudo chmod 600 $CREDENTIALS_FILE"
	exit 1
fi

echo "==> Creating systemd mount units..."
for share in "${SHARES[@]}"; do
	# Escape the mount path for systemd (replace / with -)
	unit_name=$(systemd-escape -p "${MOUNT_BASE}/${share}")

	# Create .mount unit
	sudo tee "/etc/systemd/system/${unit_name}.mount" >/dev/null <<EOF
[Unit]
Description=Mount ${share} from Synology NAS
After=network-online.target
Wants=network-online.target

[Mount]
What=//${NAS_HOST}/${share}
Where=${MOUNT_BASE}/${share}
Type=cifs
Options=credentials=${CREDENTIALS_FILE},iocharset=utf8,uid=$(id -u),gid=$(id -g),file_mode=0644,dir_mode=0755,vers=3.0,_netdev
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

	# Create .automount unit for on-demand mounting
	sudo tee "/etc/systemd/system/${unit_name}.automount" >/dev/null <<EOF
[Unit]
Description=Automount ${share} from Synology NAS
After=network-online.target
Wants=network-online.target

[Automount]
Where=${MOUNT_BASE}/${share}
TimeoutIdleSec=300

[Install]
WantedBy=multi-user.target
EOF

	echo "  Created units for ${share}"
done

echo "==> Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "==> Enabling automount units..."
for share in "${SHARES[@]}"; do
	unit_name=$(systemd-escape -p "${MOUNT_BASE}/${share}")
	sudo systemctl enable --now "${unit_name}.automount"
done

echo "==> Samba client setup complete!"
echo ""
echo "Shares will auto-mount on access at:"
for share in "${SHARES[@]}"; do
	echo "  ${MOUNT_BASE}/${share}"
done
echo ""
echo "To manually mount all shares now:"
echo "  for share in ${SHARES[*]}; do ls ${MOUNT_BASE}/\$share; done"
echo ""
echo "To check mount status:"
echo "  systemctl list-units --type=mount | grep alexandria"
