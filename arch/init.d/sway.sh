#!/usr/bin/env bash
set -euo pipefail
DOTSYS_REPO_HOME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$DOTSYS_REPO_HOME/arch/helpers.sh"
service_context "${1:---all}"
if [[ $phase == --all || $phase == --packages ]]; then
  sudo pacman -S --needed --noconfirm sway sway-contrib swaybg swayidle swaylock \
    xdg-desktop-portal-wlr xorg-xwayland autotiling-rs libpulse rofi-wayland \
    ghostty foot wl-clipboard wl-clip-persist cliphist kanshi uwsm greetd greetd-tuigreet \
    pipewire wireplumber jq
  command -v paru >/dev/null || helper_fail 'Install the reviewed paru provider via arch/preflight.sh before Sway provisioning.'
  paru -S --needed --noconfirm quickshell
fi
if [[ $phase == --all || $phase == --prepare ]]; then
  helper_need qs uwsm
  for legacy in "$XDG_CONFIG_HOME/systemd/user/dotshell.service" "$XDG_CONFIG_HOME/systemd/user/graphical-session.target.wants/dotshell.service"; do
    [[ ! -e $legacy && ! -L $legacy ]] || helper_fail 'Existing dotshell service must be reconciled explicitly before preparing quickshell.service.'
  done
  { session_exports; printf '%s\n' 'exec uwsm start default'; } | service_file "$prepared/dotsys-sway-session" 755
  mkdir -p "$XDG_CONFIG_HOME/uwsm"
  # Default session choices are staged, not changed ahead of readiness.
  printf '%s\n' sway.desktop | service_file "$prepared/default-id"
  # Only create the compatibility override on machines with the NVIDIA module.
  if lsmod | grep -q '^nvidia '; then
    service_file "$prepared/sway.desktop" <<'EOF'
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
Exec=sway --unsupported-gpu
Type=Application
DesktopNames=sway;wlroots
EOF
  fi
  config=${XDG_CONFIG_HOME//\\/\\\\}; config=${config//\"/\\\"}; config=${config//%/%%}
  service_file "$prepared/quickshell.service" <<EOF
[Unit]
Description=dotshell desktop shell
PartOf=graphical-session.target
After=graphical-session.target
[Service]
ExecStart=/usr/bin/env qs -p "$config/dotshell"
Restart=on-failure
RestartSec=3
[Install]
WantedBy=graphical-session.target
EOF
fi
if [[ $phase == --all || $phase == --activate ]]; then
  sudo install -Dm755 "$prepared/dotsys-sway-session" /usr/local/bin/dotsys-sway-session
  service_link "$prepared/default-id" "$XDG_CONFIG_HOME/uwsm/default-id"
  if [[ -f $prepared/sway.desktop ]]; then
    service_link "$prepared/sway.desktop" "$XDG_DATA_HOME/wayland-sessions/sway.desktop"
  fi
  systemctl --user daemon-reload
  systemctl --user enable "$prepared/quickshell.service"
  if [[ -n ${SWAYSOCK:-} ]]; then systemctl --user restart quickshell.service; fi
fi

# Retained full-machine conveniences are explicit, not core requirements.
if [[ $phase == --all || $phase == --extras ]]; then
  sudo pacman -S --needed --noconfirm rofi-calc flameshot wev
  paru -S --needed --noconfirm swaylock-effects
  mkdir -p "$HOME/Pictures"
  cp -r "$DOTSYS_REPO_HOME/wallpapers" "$HOME/Pictures/"
fi
