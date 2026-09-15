#!/usr/bin/env bash
set -euo pipefail
DOTSYS_REPO_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$DOTSYS_REPO_HOME/arch/helpers.sh"
service_context "${1:---all}"
if [[ $phase == --all || $phase == --packages ]]; then sudo xbps-install -Sy greetd tuigreet; fi
if [[ $phase == --all || $phase == --prepare ]]; then
  service_file "$prepared/greetd.toml" <<'EOF'
[terminal]
vt = 1
[default_session]
command = "tuigreet --time --remember --cmd sway-session"
user = "_greeter"
EOF
fi
if [[ $phase == --all || $phase == --activate ]]; then
  sudo install -Dm644 "$prepared/greetd.toml" /etc/greetd/config.toml
  sudo mkdir -p /var/cache/tuigreet
  sudo chown _greeter:_greeter /var/cache/tuigreet
  # Only the final successful activation may take over VT1.
  if [[ -e /var/service/greetd || -L /var/service/greetd ]]; then
    [[ $(readlink /var/service/greetd) == /etc/sv/greetd ]] || helper_fail 'Conflicting greetd registration.'
  fi
  if [[ -e /var/service/agetty-tty1 || -L /var/service/agetty-tty1 ]]; then
    [[ -L /var/service/agetty-tty1 && $(readlink /var/service/agetty-tty1) == /etc/sv/agetty-tty1 ]] || helper_fail 'Conflicting VT1 registration.'
    sudo rm /var/service/agetty-tty1
  fi
  if [[ ! -L /var/service/greetd ]]; then sudo ln -sT /etc/sv/greetd /var/service/greetd; fi
fi
