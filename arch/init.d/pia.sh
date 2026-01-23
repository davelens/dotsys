#!/usr/bin/env bash
set -e

echo "==> Installing Private Internet Access ..."

DOWNLOAD_URL=$(curl -s https://www.privateinternetaccess.com/download/linux-vpn |
  grep -oE 'https://installers\.privateinternetaccess\.com/download/pia-linux-[0-9.]+-[0-9]+\.run' |
  head -1)

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Error: Could not find PIA download URL"
  exit 1
fi

echo "Downloading from: $DOWNLOAD_URL"

INSTALLER="/tmp/pia-installer.run"
curl -L -o "$INSTALLER" "$DOWNLOAD_URL"
chmod +x "$INSTALLER"
"$INSTALLER"
rm -f "$INSTALLER"

sudo systemctl start piavpn
sudo systemctl enable piavpn

echo "==> PIA installation complete!"
