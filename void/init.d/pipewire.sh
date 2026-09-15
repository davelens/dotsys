#!/usr/bin/env bash
set -euo pipefail
DOTSYS_REPO_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$DOTSYS_REPO_HOME/arch/helpers.sh"
service_context "${1:---all}"
if [[ $phase == --all || $phase == --packages ]]; then sudo xbps-install -Sy pipewire wireplumber; fi
if [[ $phase == --all || $phase == --prepare ]]; then
  service_file "$prepared/pipewire-exec.conf" <<'EOF'
context.exec = [
    { path = "/usr/bin/wireplumber" args = "" }
    { path = "/usr/bin/pipewire" args = "-c pipewire-pulse.conf" }
]
EOF
  service_file "$prepared/pipewire/run" 755 <"$DOTSYS_REPO_HOME/void/user-services/pipewire/run"
fi
if [[ $phase == --all || $phase == --activate ]]; then
  sudo install -Dm644 "$prepared/pipewire-exec.conf" /etc/pipewire/pipewire.conf.d/10-exec.conf
  service_link "$prepared/pipewire" "$XDG_CONFIG_HOME/service/pipewire"
fi
