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

"$DOTSYS_REPO_HOME/void/preflight.sh"
"$DOTSYS_REPO_HOME/void/init.d/sway.sh"
"$DOTSYS_REPO_HOME/void/init.d/greetd.sh"
"$DOTSYS_REPO_HOME/void/init.d/turnstile.sh" # after greetd.sh (patches its PAM file)
"$DOTSYS_REPO_HOME/void/init.d/pipewire.sh"
"$DOTSYS_REPO_HOME/void/init.d/waybar.sh"
"$DOTSYS_REPO_HOME/void/init.d/kanshi.sh"

# Not ported from arch/ yet: wifi (iwd), bluetooth-autoconnect, kanata,
# power-profiles, samba, databases. Port them here when needed.

echo "==> Void bootstrap complete. Reboot (or log out) to land in greetd."
