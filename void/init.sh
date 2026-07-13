#!/usr/bin/env bash
# Void Linux bootstrap — sway desktop on runit.
#
# Architectural note: Void keeps system and user service supervision on runit,
# while elogind supplies the desktop-facing logind interface:
#
#   uwsm start default   -> greetd runs `sway-session` wrapper directly
#   logind               -> elogind (sessions, seats, power, polkit identity)
#   systemd user units   -> turnstile-managed runit services in ~/.config/service/
#   session dbus         -> turnstile dbus user service (shared bus, /run/user/$UID/bus)
#
# Turnstile does not manage XDG_RUNTIME_DIR in this arrangement; elogind does.
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

# Switching VT1 from agetty to greetd terminates any shell running there, so
# this must be the final setup step, after all session infrastructure is ready.
if [ -e /var/service/agetty-tty1 ] || [ -L /var/service/agetty-tty1 ]; then
  echo "==> Disabling agetty on VT1..."
  sudo rm -f /var/service/agetty-tty1
fi
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
