#!/usr/bin/env bash
set -euo pipefail
DOTSYS_REPO_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$DOTSYS_REPO_HOME/arch/helpers.sh"
service_context "${1:---all}"
if [[ $phase == --all || $phase == --packages ]]; then sudo xbps-install -Sy kanshi; fi
if [[ $phase == --all || $phase == --prepare ]]; then
  service_file "$prepared/kanshi/run" 755 <"$DOTSYS_REPO_HOME/void/user-services/kanshi/run"
fi
if [[ $phase == --all || $phase == --activate ]]; then
  service_link "$prepared/kanshi" "$XDG_CONFIG_HOME/service/kanshi"
fi
