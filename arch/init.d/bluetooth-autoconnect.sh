#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install the autoconnect script
mkdir -p ~/.local/bin
cat >~/.local/bin/bluetooth-autoconnect <<'EOF'
#!/usr/bin/env bash
#
# Auto-connect trusted Bluetooth devices when they appear
# Monitors BlueZ via D-Bus and connects devices that are trusted but not connected
#

POLL_INTERVAL=5

get_trusted_devices() {
	busctl tree org.bluez 2>/dev/null | grep -oP '/org/bluez/hci0/dev_[A-F0-9_]+' | sort -u
}

is_trusted() {
	local dev="$1"
	[[ "$(busctl get-property org.bluez "$dev" org.bluez.Device1 Trusted 2>/dev/null | awk '{print $2}')" == "true" ]]
}

is_connected() {
	local dev="$1"
	[[ "$(busctl get-property org.bluez "$dev" org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}')" == "true" ]]
}

connect_device() {
	local dev="$1"
	busctl call org.bluez "$dev" org.bluez.Device1 Connect 2>/dev/null
}

main() {
	while true; do
		for dev in $(get_trusted_devices); do
			if is_trusted "$dev" && ! is_connected "$dev"; then
				connect_device "$dev"
			fi
		done
		sleep "$POLL_INTERVAL"
	done
}

main
EOF
chmod +x ~/.local/bin/bluetooth-autoconnect

# Enable and start the service
systemctl --user daemon-reload
systemctl --user enable "$SCRIPT_DIR/../systemd/bluetooth-autoconnect.service"
systemctl --user restart bluetooth-autoconnect

echo "Bluetooth autoconnect service installed and started"
