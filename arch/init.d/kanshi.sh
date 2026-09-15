#!/usr/bin/env bash
set -euo pipefail
DOTSYS_REPO_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$DOTSYS_REPO_HOME/arch/helpers.sh"
service_context "${1:---all}"
if [[ $phase == --all || $phase == --packages ]]; then
  sudo pacman -S --needed --noconfirm kanshi
fi
if [[ $phase == --all || $phase == --prepare ]]; then
  service_file "$prepared/kanshi.service" <"$DOTSYS_REPO_HOME/arch/systemd/kanshi.service"
fi
if [[ $phase == --all || $phase == --activate ]]; then
  systemctl --user daemon-reload
  systemctl --user enable "$prepared/kanshi.service"
  if [[ -n ${SWAYSOCK:-} ]]; then systemctl --user restart kanshi; fi
fi
