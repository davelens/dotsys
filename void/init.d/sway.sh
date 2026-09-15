#!/usr/bin/env bash
set -euo pipefail
DOTSYS_REPO_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$DOTSYS_REPO_HOME/arch/helpers.sh"
service_context "${1:---all}"
if [[ $phase == --all || $phase == --packages ]]; then
  sudo xbps-install -Sy sway swaybg swayidle swaylock grimshot \
    xdg-desktop-portal-wlr xorg-server-xwayland autotiling rofi ghostty foot \
    wl-clipboard wl-clip-persist cliphist kanshi quickshell jq \
    elogind turnstile lxqt-policykit dbus greetd tuigreet pipewire wireplumber
fi
if [[ $phase == --all || $phase == --prepare ]]; then
  helper_need qs autotiling turnstile-update-runit-env
  [[ ! -e $XDG_CONFIG_HOME/service/dotshell && ! -L $XDG_CONFIG_HOME/service/dotshell ]] || helper_fail 'Existing dotshell service must be reconciled explicitly before preparing quickshell.'
  { session_exports; cat <<'EOF'
shared_env="${XDG_CONFIG_HOME:-$HOME/.config}/desktop-session/env"
if [ -r "$shared_env" ]; then . "$shared_env"; fi
export XDG_CURRENT_DESKTOP=sway
if lsmod | grep -q '^nvidia '; then exec sway --unsupported-gpu; fi
exec sway
EOF
  } | service_file "$prepared/sway-session" 755
  # Reuse the reviewed dotshell login-session launcher, not its activating setup.
  # The upstream script currently embeds HOME/.config and a forced renderer.
  [[ -f ${DOTSYS_DOTSHELL_ROOT:-}/setup/dotshell.run ]] || helper_fail 'Supply DOTSYS_DOTSHELL_ROOT with setup/dotshell.run.'
  python3 -I -B - "$DOTSYS_DOTSHELL_ROOT/setup/dotshell.run" "$XDG_CONFIG_HOME" <<'PY' | service_file "$prepared/quickshell/run" 755
import pathlib, shlex, sys
text = pathlib.Path(sys.argv[1]).read_text()
old = 'exec /usr/bin/quickshell -p "$HOME/.config/dotshell"'
if old not in text:
    sys.exit('Unrecognized dotshell launcher; inspect its new interface before preparing.')
text = text.replace(old, 'exec qs -p "$XDG_CONFIG_HOME/dotshell"')
text = text.replace('export QSG_RHI_BACKEND="\\${QSG_RHI_BACKEND:-vulkan}"\n', '')
print('#!/bin/sh\nexport XDG_CONFIG_HOME=' + shlex.quote(sys.argv[2]))
print(text)
PY
fi
if [[ $phase == --all || $phase == --activate ]]; then
  sudo install -Dm755 "$prepared/sway-session" /usr/local/bin/sway-session
  service_link "$prepared/quickshell" "$XDG_CONFIG_HOME/service/quickshell"
fi

if [[ $phase == --all || $phase == --extras ]]; then
  sudo xbps-install -Sy rofi-calc flameshot wev
  mkdir -p "$HOME/Pictures"
  cp -r "$DOTSYS_REPO_HOME/wallpapers" "$HOME/Pictures/"
fi
