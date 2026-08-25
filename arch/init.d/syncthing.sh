#!/usr/bin/env bash
set -euo pipefail

# Syncthing setup + pairing for framework-laptop <-> framework-desktop.
# Syncs ~/.config/pi/sessions so pi agent history is shared between machines.
#
# Run on each machine. Second run (after peer also set up) will pair them via
# SSH using the alias defined in ~/.ssh/config.
#
# Usage:
#   ./syncthing.sh              # install + configure local, attempt pairing
#   PEER_SSH=other ./syncthing.sh   # override peer SSH host

FOLDER_ID="pi-sessions"
FOLDER_PATH="$HOME/.config/pi/sessions"
FOLDER_LABEL="Pi Sessions"

echo "==> Installing syncthing + hostname..."
sudo pacman -S --needed --noconfirm syncthing inetutils

case "$(hostname)" in
  framework-laptop)  DEFAULT_PEER="framework-desktop" ;;
  framework-desktop) DEFAULT_PEER="framework-laptop" ;;
  desktop)           DEFAULT_PEER="framework-desktop" ;;
  *) DEFAULT_PEER="" ;;
esac
PEER_SSH="${PEER_SSH:-$DEFAULT_PEER}"

echo "==> Enabling user service..."
systemctl --user enable --now syncthing.service
loginctl enable-linger "$USER" >/dev/null 2>&1 || sudo loginctl enable-linger "$USER"

CFG="$HOME/.local/state/syncthing/config.xml"
[ -f "$CFG" ] || CFG="$HOME/.config/syncthing/config.xml"

echo "==> Waiting for config.xml..."
for _ in {1..30}; do [ -f "$CFG" ] && break; sleep 1; done
[ -f "$CFG" ] || { echo "config.xml missing after 30s"; exit 1; }

get_key()  { grep -oP '(?<=<apikey>)[^<]+' "$1"; }
get_addr() { awk '/<gui /,/<\/gui>/' "$1" | grep -oP '(?<=<address>)[^<]+'; }

KEY=$(get_key "$CFG")
ADDR=$(get_addr "$CFG")
SC=(syncthing cli --gui-address="$ADDR" --gui-apikey="$KEY")

echo "==> Waiting for REST API..."
for _ in {1..30}; do "${SC[@]}" show system >/dev/null 2>&1 && break; sleep 1; done

MY_ID=$("${SC[@]}" show system | jq -r .myID)
echo "    local device ID: $MY_ID"

echo "==> Ensuring folder $FOLDER_ID exists..."
mkdir -p "$FOLDER_PATH"
if ! "${SC[@]}" config folders list | grep -qx "$FOLDER_ID"; then
  "${SC[@]}" config folders add \
    --id "$FOLDER_ID" --label "$FOLDER_LABEL" --path "$FOLDER_PATH"
fi

echo "==> Opening firewall (22000/tcp, 21027/udp)..."
if command -v ufw >/dev/null && sudo ufw status | grep -q active; then
  sudo ufw allow 22000/tcp >/dev/null
  sudo ufw allow 21027/udp >/dev/null
elif command -v firewall-cmd >/dev/null; then
  sudo firewall-cmd --add-port=22000/tcp --add-port=21027/udp --permanent >/dev/null
  sudo firewall-cmd --reload >/dev/null
fi

if [ -z "$PEER_SSH" ]; then
  echo "==> No peer configured. Done. Set PEER_SSH= and rerun to pair."
  exit 0
fi

SSH_CTL=$(mktemp -u /tmp/ssh-syncthing-XXXX.sock)
trap 'ssh -O exit -o ControlPath=$SSH_CTL $PEER_SSH 2>/dev/null || true; rm -f $SSH_CTL' EXIT
SSH_OPTS=(-o ControlMaster=auto -o ControlPath="$SSH_CTL" -o ControlPersist=60 -o ConnectTimeout=10)

echo "==> Fetching peer device ID via ssh $PEER_SSH..."
if ! PEER_ID=$(ssh "${SSH_OPTS[@]}" "$PEER_SSH" '
    CFG=$HOME/.local/state/syncthing/config.xml
    [ -f "$CFG" ] || CFG=$HOME/.config/syncthing/config.xml
    [ -f "$CFG" ] || { echo "no-config"; exit 1; }
    KEY=$(grep -oP "(?<=<apikey>)[^<]+" "$CFG")
    ADDR=$(awk "/<gui /,/<\\/gui>/" "$CFG" | grep -oP "(?<=<address>)[^<]+")
    syncthing cli --gui-address=$ADDR --gui-apikey=$KEY show system | jq -r .myID
  '); then
  echo "    SSH to $PEER_SSH failed. Run script on peer first, then rerun here."
  exit 0
fi

[ "$PEER_ID" = "no-config" ] && { echo "    peer has no syncthing config yet"; exit 0; }
echo "    peer device ID: $PEER_ID"

echo "==> Registering peer locally..."
"${SC[@]}" config devices add --device-id "$PEER_ID" --name "$PEER_SSH" 2>/dev/null || true
"${SC[@]}" config folders "$FOLDER_ID" devices add --device-id "$PEER_ID" 2>/dev/null || true

echo "==> Registering self on peer..."
ssh "${SSH_OPTS[@]}" "$PEER_SSH" "
  CFG=\$HOME/.local/state/syncthing/config.xml
  [ -f \"\$CFG\" ] || CFG=\$HOME/.config/syncthing/config.xml
  KEY=\$(grep -oP '(?<=<apikey>)[^<]+' \"\$CFG\")
  ADDR=\$(awk '/<gui /,/<\\/gui>/' \"\$CFG\" | grep -oP '(?<=<address>)[^<]+')
  SC='syncthing cli --gui-address='\$ADDR' --gui-apikey='\$KEY
  \$SC config devices add --device-id $MY_ID --name $(hostname) 2>/dev/null || true
  \$SC config folders list | grep -qx $FOLDER_ID || \$SC config folders add --id $FOLDER_ID --label \"$FOLDER_LABEL\" --path $FOLDER_PATH
  \$SC config folders $FOLDER_ID devices add --device-id $MY_ID 2>/dev/null || true
"

echo "==> Verifying connection..."
sleep 3
"${SC[@]}" show connections | jq --arg id "$PEER_ID" '.connections[$id] | {connected, address}'

echo "==> Done."
