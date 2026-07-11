#!/usr/bin/env bash
set -e

echo "==> Installing turnstile + seatd (uwsm/logind replacement)..."

# turnstile: session tracker + per-user runit service trees (Void builds it
# with a runit backend as default). seatd: seat management (sway needs it
# without elogind). acpid: lid/power buttons, also elogind's job normally.
sudo xbps-install -Sy turnstile seatd acpid

sudo ln -sf /etc/sv/seatd /var/service/
sudo ln -sf /etc/sv/acpid /var/service/
sudo ln -sf /etc/sv/turnstiled /var/service/

# Seat access for the desktop user.
desktop_user="$(id -un)"
sudo usermod -aG _seatd "$desktop_user"

# Hook turnstile into greetd's login path so the user service tree starts
# at login. greetd.sh must have run first (it installs /etc/pam.d/greetd).
if ! sudo grep -q 'pam_turnstile' /etc/pam.d/greetd; then
  echo 'session optional pam_turnstile.so' | sudo tee -a /etc/pam.d/greetd >/dev/null
  echo "==> Added pam_turnstile to /etc/pam.d/greetd"
fi

# Session dbus as a turnstile user service: one shared bus per user at
# /run/user/$UID/bus, exported into the login env by turnstiled.
mkdir -p "$HOME/.config/service/dbus"
ln -sf /usr/share/examples/turnstile/dbus.run "$HOME/.config/service/dbus/run"
ln -sf /usr/share/examples/turnstile/dbus.check "$HOME/.config/service/dbus/check"

# Block login until the session bus is up.
mkdir -p "$HOME/.config/service/turnstile-ready"
echo 'core_services="dbus"' >"$HOME/.config/service/turnstile-ready/conf"
