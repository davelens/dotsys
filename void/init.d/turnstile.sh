#!/usr/bin/env bash
set -euo pipefail
DOTSYS_REPO_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$DOTSYS_REPO_HOME/arch/helpers.sh"
service_context "${1:---all}"
if [[ $phase == --all || $phase == --packages ]]; then
  sudo xbps-install -Sy elogind turnstile lxqt-policykit
fi
if [[ $phase == --all || $phase == --prepare ]]; then
  # No runit registration (including user services) before readiness.
  sudo cat /usr/share/examples/turnstile/dbus.run | service_file "$prepared/dbus/run" 755
  sudo cat /usr/share/examples/turnstile/dbus.check | service_file "$prepared/dbus/check" 755
  service_file "$prepared/lxqt-policykit/run" 755 <"$DOTSYS_REPO_HOME/void/user-services/lxqt-policykit/run"
  printf '%s\n' 'core_services="dbus"' | service_file "$prepared/turnstile-ready.conf"
  # Upstream backend/runit.conf defaults to HOME/.config (not XDG). Both the
  # backend and turnstile-update-runit-env source this explicit configuration.
  existing=$(sudo cat /etc/turnstile/backend/runit.conf)
  printf '%s\n' "$existing" | python3 -I -B -c '
import os, shlex, sys
text = sys.stdin.read()
uid = sys.argv[1]
begin, end = "# dotsys user " + uid + " begin", "# dotsys user " + uid + " end"
if begin in text or end in text:
    if text.count(begin) != 1 or text.count(end) != 1 or text.index(begin) > text.index(end):
        sys.exit("Malformed dotsys turnstile block; preserve and reconcile explicitly")
    left, tail = text.split(begin)
    _, right = tail.split(end)
    text = left + right.lstrip("\n")
print(text.rstrip())
print(begin)
print("if [ \"$(id -u)\" = " + shlex.quote(uid) + " ]; then")
for key in ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_BIN_HOME"):
    print("  export " + key + "=" + shlex.quote(os.environ[key]))
print("  services_dir=" + shlex.quote(os.environ["XDG_CONFIG_HOME"] + "/service"))
print("  service_env_dir=" + shlex.quote(os.environ["XDG_CONFIG_HOME"] + "/service-env"))
print("fi\n" + end)
' "$(id -u)" | service_file "$prepared/runit.conf"
fi
if [[ $phase == --all || $phase == --activate ]]; then
  sudo install -Dm644 "$prepared/runit.conf" /etc/turnstile/backend/runit.conf
  # elogind owns the runtime directory; turnstile owns user supervision only.
  if sudo grep -q '^[[:space:]]*manage_rundir[[:space:]]*=' /etc/turnstile/turnstiled.conf; then
    sudo sed -i 's/^[[:space:]]*manage_rundir[[:space:]]*=.*/manage_rundir = no/' /etc/turnstile/turnstiled.conf
  else
    echo 'manage_rundir = no' | sudo tee -a /etc/turnstile/turnstiled.conf >/dev/null
  fi
  sudo sed -i '/^session optional pam_turnstile\.so$/d' /etc/pam.d/greetd
  for service in seatd acpid; do
    if [[ -d /etc/sv/$service ]]; then
      sudo touch "/etc/sv/$service/down"
      if [[ $service != seatd || -z ${SWAYSOCK:-} ]]; then sudo sv down "/var/service/$service"; fi
    fi
  done
  if [[ -L /var/service/elogind ]]; then
    [[ $(readlink /var/service/elogind) == /etc/sv/elogind ]] || helper_fail 'Conflicting elogind registration.'
    sudo rm /var/service/elogind
  fi
  if [[ -e /var/service/turnstiled || -L /var/service/turnstiled ]]; then
    [[ $(readlink /var/service/turnstiled) == /etc/sv/turnstiled ]] || helper_fail 'Conflicting turnstiled registration.'
  else
    sudo ln -sT /etc/sv/turnstiled /var/service/turnstiled
  fi
  ready=false
  for _ in {1..40}; do
    if sudo sv status /var/service/turnstiled >/dev/null 2>&1; then ready=true; break; fi
    sleep 0.25
  done
  $ready || helper_fail 'turnstiled did not become supervised.'
  sudo sv restart /var/service/turnstiled
  for service in dbus lxqt-policykit; do
    service_link "$prepared/$service" "$XDG_CONFIG_HOME/service/$service"
  done
  service_link "$prepared/turnstile-ready.conf" "$XDG_CONFIG_HOME/service/turnstile-ready/conf"
fi
