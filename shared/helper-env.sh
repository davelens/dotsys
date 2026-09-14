# Direct helper bootstrap only; never source dotfiles startup or private env.
helper_fail() { printf 'dotsys: %s\n' "$*" >&2; exit 1; }
helper_need() {
  local command
  for command in "$@"; do
    type -P "$command" >/dev/null || helper_fail "Missing $command; prepare this capability with dotsys before retrying."
  done
}

[[ ${BASH_VERSINFO[0]} -ge 5 ]] || helper_fail 'Bash 5 or newer is required.'
[[ ${HOME:-} == /* ]] || helper_fail 'Set HOME to the invoking user’s absolute home path.'
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
for helper_path in "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_BIN_HOME"; do
  [[ $helper_path == /* ]] || helper_fail 'HOME/XDG paths must be absolute.'
done
# Do not create or synthesize a session/runtime directory.
[[ -z ${XDG_RUNTIME_DIR:-} || $XDG_RUNTIME_DIR == /* ]] || helper_fail 'XDG_RUNTIME_DIR must be absolute.'

# Explicit platform input is also used by the provisioning handoff.
if [[ ! ${DOTSYS_PLATFORM+x} ]]; then
  case "$(uname -s)" in
    Darwin) DOTSYS_PLATFORM=macos ;;
    Linux)
      DOTSYS_PLATFORM=unsupported
      while IFS='=' read -r key value; do
        [[ $key == ID ]] || continue
        value=${value//\"/}
        value=${value//\'/}
        case "$value" in arch|void) DOTSYS_PLATFORM=$value ;; esac
      done < /etc/os-release
      if [[ $DOTSYS_PLATFORM == arch && $(uname -r) == *[Mm]icrosoft* ]]; then
        DOTSYS_PLATFORM=wsl
      fi
      ;;
    *) DOTSYS_PLATFORM=unsupported ;;
  esac
fi
case "$DOTSYS_PLATFORM" in
  arch|wsl|void|macos) export DOTSYS_PLATFORM ;;
  *) helper_fail 'Unsupported platform; expected Arch, Arch WSL, Void, or macOS.' ;;
esac
