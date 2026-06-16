#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

# Enable lingering so the other user-scope session services start at boot.
# Kanata itself runs as a *system* service (see below), so it no longer
# depends on lingering, but leaving this here is harmless and idempotent.
sudo loginctl enable-linger "$USER"

# Create uinput as a system group. udev deprecates non-system groups owning
# device nodes, so recreate it if an old non-system (GID >= 1000) one exists.
uinput_gid="$(getent group uinput | cut -d: -f3)"
if [ -z "$uinput_gid" ]; then
	sudo groupadd -r uinput
elif [ "$uinput_gid" -ge 1000 ]; then
	sudo groupdel uinput
	sudo groupadd -r uinput
fi

# Ensure user is in input and uinput groups for device access
sudo usermod -aG input,uinput "$USER"

# Create udev rule for uinput device permissions
echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"' |
	sudo tee /etc/udev/rules.d/99-input.rules >/dev/null
sudo udevadm control --reload-rules && sudo udevadm trigger

paru -S --needed --noconfirm kanata-bin

# Kanata runs as system services so the uinput supplementary group is honoured
# (a lingering user manager captures groups at boot and never refreshes them,
# dropping uinput). Tear down any legacy user-scope units from the old setup.
systemctl --user disable --now kanata.service kanata-external.service 2>/dev/null || true

sudo systemctl daemon-reload

# Only enable the internal keyboard service if a Framework keyboard is present.
# On other machines, only the external/named-keyboard service is needed.
if ls /dev/input/by-id/*Framework* &>/dev/null; then
	sudo systemctl enable "$DOTSYS_REPO_HOME/arch/systemd/kanata-internal.service"
	sudo systemctl restart kanata-internal.service
else
	sudo systemctl disable --now kanata-internal.service 2>/dev/null || true
fi

sudo systemctl enable "$DOTSYS_REPO_HOME/arch/systemd/kanata-external.service"
sudo systemctl restart kanata-external.service

# When you press capslock while Kanata is starting, you might end up with an
# active capslock and no conventional way to turn it off.
echo
echo "Kanata is booting; DO NOT PRESS CAPSLOCK"
sleep 2
printf "\033[2A\033[0J"
echo -e "Kanata is ready!\n"
