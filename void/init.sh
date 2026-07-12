#!/usr/bin/env bash
# Void Linux bootstrap — sway desktop on runit.
#
# Architectural note: on Arch this repo uses uwsm + systemd user units.
# Neither exists on Void (runit, no systemd), so the session stack is:
#
#   uwsm start default   -> greetd runs `sway-session` wrapper directly
#   logind (sessions)    -> turnstile (turnstiled + pam_turnstile)
#   logind (seats)       -> seatd
#   systemd user units   -> turnstile-managed runit services in ~/.config/service/
#   session dbus         -> turnstile dbus user service (shared bus, /run/user/$UID/bus)
#
# Run as the desktop user (needs sudo). Assumes a base install produced by
# the davelens/void repo (NetworkManager, dbus already enabled).
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$(id -u)" -eq 0 ]; then
  echo "error: run this script as your desktop user, without sudo" >&2
  echo "individual system changes will ask for sudo when needed" >&2
  exit 1
fi

"$DOTSYS_REPO_HOME/void/preflight.sh"
"$DOTSYS_REPO_HOME/void/packages/init.sh"
"$DOTSYS_REPO_HOME/void/init.d/sway.sh"
"$DOTSYS_REPO_HOME/void/init.d/greetd.sh"
"$DOTSYS_REPO_HOME/void/init.d/turnstile.sh" # after greetd.sh (patches its PAM file)
"$DOTSYS_REPO_HOME/void/init.d/pipewire.sh"
"$DOTSYS_REPO_HOME/void/init.d/kanshi.sh"

# Enabling greetd takes over VT1 immediately, so it must be the final setup
# step, after turnstile has installed its PAM hook and runtime-dir manager.
if [ ! -L /var/service/greetd ]; then
  echo "==> Enabling greetd (takes over VT1 immediately!)"
  sudo ln -s /etc/sv/greetd /var/service/
fi

# Optional components, intentionally not installed by default:
# "$DOTSYS_REPO_HOME/void/init.d/waybar.sh"
#
# Not ported from arch/ yet: wifi (iwd), bluetooth-autoconnect, kanata,
# power-profiles, samba, databases. Port them here when needed.

echo "==> Void bootstrap complete. Reboot (or log out) to land in greetd."
