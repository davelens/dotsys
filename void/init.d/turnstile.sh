#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Installing elogind + turnstile session stack..."

# elogind provides the logind-compatible session, seat, power, and polkit
# identity expected by desktop software. Turnstile remains solely for the
# per-user runit service tree that elogind does not provide.
sudo xbps-install -Sy elogind turnstile lxqt-policykit

# elogind owns /run/user/$UID. Turnstile may export the path and shared D-Bus
# address, but must not create or remove the runtime directory as well.
if sudo grep -q '^[[:space:]]*manage_rundir[[:space:]]*=' /etc/turnstile/turnstiled.conf; then
  sudo sed -i 's/^[[:space:]]*manage_rundir[[:space:]]*=.*/manage_rundir = no/' \
    /etc/turnstile/turnstiled.conf
else
  echo 'manage_rundir = no' | sudo tee -a /etc/turnstile/turnstiled.conf >/dev/null
fi

# Void's system-login PAM stack already opens both pam_elogind and
# pam_turnstile, and greetd includes that stack through system-local-login.
# Remove the redundant line written by older versions of this bootstrap.
sudo sed -i '/^session optional pam_turnstile\.so$/d' /etc/pam.d/greetd

# elogind replaces seatd for seat access and acpid for lid/power events. Mark
# both alternatives down so they stay disabled after reboot. Stopping seatd
# underneath a live Sway session would terminate that session, so defer only
# that stop until logout when this bootstrap is run graphically.
for service in seatd acpid; do
  if [ -d "/etc/sv/$service" ]; then
    echo "==> Disabling superseded $service service..."
    sudo touch "/etc/sv/$service/down"
    if [[ "$service" != seatd || -z "${SWAYSOCK:-}" ]]; then
      sudo sv down "/var/service/$service" 2>/dev/null || true
    else
      echo "    seatd will stop after logout/reboot."
    fi
  fi
done

# elogind is D-Bus activated on Void. Enabling its runit service as well can
# race that activation during boot, leaving runit supervising an already
# running daemon. Remove a legacy explicit service link and let D-Bus own it.
if [ -e /var/service/elogind ] || [ -L /var/service/elogind ]; then
  sudo rm -f /var/service/elogind
fi
sudo ln -sfn /etc/sv/turnstiled /var/service/turnstiled

# Existing turnstile instances must reload manage_rundir=no. Newly linked
# services are discovered asynchronously by runsvdir, so wait for supervision.
ready=false
for _ in {1..40}; do
  if sudo sv status /var/service/turnstiled >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 0.25
done
if [[ "$ready" != true ]]; then
  echo "error: turnstiled did not become supervised" >&2
  exit 1
fi
sudo sv restart /var/service/turnstiled

# One shared session bus per user at /run/user/$UID/bus. Turnstile exports its
# address into the login and user-service environments.
mkdir -p "$HOME/.config/service/dbus"
ln -sfn /usr/share/examples/turnstile/dbus.run "$HOME/.config/service/dbus/run"
ln -sfn /usr/share/examples/turnstile/dbus.check "$HOME/.config/service/dbus/check"

# Graphical polkit agent for background services such as dotshell updates.
mkdir -p "$HOME/.config/service/lxqt-policykit"
ln -sfn "$DOTSYS_REPO_HOME/void/user-services/lxqt-policykit/run" \
  "$HOME/.config/service/lxqt-policykit/run"

# Block login until the session bus is available. The polkit agent may start
# immediately after login and must not hold the login open on UI failures.
mkdir -p "$HOME/.config/service/turnstile-ready"
echo 'core_services="dbus"' >"$HOME/.config/service/turnstile-ready/conf"
