#!/usr/bin/env bash
set -euo pipefail
DOTSYS_REPO_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$DOTSYS_REPO_HOME/arch/helpers.sh"
service_context "${1:---all}"
if [[ $phase == --all || $phase == --packages ]]; then
  sudo pacman -S --needed --noconfirm greetd greetd-tuigreet
fi
if [[ $phase == --all || $phase == --prepare ]]; then
  service_file "$prepared/greetd.toml" <<'EOF'
[terminal]
vt = 1
[default_session]
command = "tuigreet --time --remember --remember-user-session --cmd dotsys-sway-session"
user = "greeter"
EOF
fi
if [[ $phase == --all || $phase == --activate ]]; then
  sudo install -Dm644 "$prepared/greetd.toml" /etc/greetd/config.toml
  sudo systemctl enable greetd.service
fi
