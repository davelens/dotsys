#!/usr/bin/env bash
# Deliberately Bash 3.2 compatible until native bootstrap supplies Bash 5.
set -eo pipefail
set +x
root=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail() { printf 'dotsys: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage: shared/install.sh [setup] --platform arch|void|macos|wsl [OPTIONS]
  --dotfiles-root ABS   Stable checkout (default: sibling dotfiles)
  --dotvim-root ABS     Stable checkout (default: sibling dotvim)
  --dotshell-root ABS   Stable checkout (default: sibling dotshell)
  --home ABS --user USER --xdg-config-home ABS --xdg-data-home ABS
  --xdg-state-home ABS --xdg-cache-home ABS --xdg-bin-home ABS
  --select CSV --wezterm-destination PATH --save
  --adopt EXACT_PATH / --replace EXACT_PATH (dotfiles artifacts)
  --helper-adopt EXACT_PATH / --helper-replace EXACT_PATH (dotsys artifacts)
  --full-machine       Compose the previous platform workflow after readiness
Setup aliases: setup --arch | --void | --dotsys PLATFORM runs the handoff.
setup --dotvim | --dotshell acquires/registers only those tools on a prepared
machine; --platform is optional provider context, not a request for provisioning.
setup --dotfiles invokes only the prepared checkout's configuration installer.
--arch/--void default to Sway only without explicit choices or a saved env file.
Acquisition sources: DOTSYS_DOTFILES_SOURCE, DOTSYS_DOTVIM_SOURCE,
DOTSYS_DOTSHELL_SOURCE (known public origins or explicit absolute local Git sources).
No stage rolls back completed work. Readiness failure prevents activation.
EOF
}
platform=${DOTSYS_PLATFORM:-}
dotfiles=${DOTSYS_DOTFILES_ROOT:-${root%/*}/dotfiles}
dotvim=${DOTSYS_DOTVIM_ROOT:-${root%/*}/dotvim}
dotshell=${DOTSYS_DOTSHELL_ROOT:-${root%/*}/dotshell}
choices=() approvals=() helper_approvals=()
full=false want_shell=false want_vim=false want_config=false default_selection=
setup=false machine=false
if [[ ${1:-} == setup ]]; then setup=true; shift; fi
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --full-machine) full=true; machine=true; shift ;;
    --arch|--void) platform=${1#--}; default_selection=sway; machine=true; shift ;;
    --dotfiles) want_config=true; shift ;;
    --dotvim) want_vim=true; shift ;;
    --dotshell) want_shell=true; shift ;;
    --save) choices+=("$1"); shift ;;
    --platform|--dotsys|--dotfiles-root|--dotvim-root|--dotshell-root|--home|--user|--xdg-config-home|--xdg-data-home|--xdg-state-home|--xdg-cache-home|--xdg-bin-home|--select|--wezterm-destination|--adopt|--replace|--helper-adopt|--helper-replace)
      [[ $# -ge 2 ]] || fail "Missing value for $1"
      case $1 in
        --platform) platform=$2 ;;
        --dotsys) platform=$2; machine=true ;;
        --dotfiles-root) dotfiles=$2 ;; --dotvim-root) dotvim=$2 ;; --dotshell-root) dotshell=$2 ;;
        --home) export HOME=$2 ;; --user) export USER=$2 ;;
        --xdg-config-home) export XDG_CONFIG_HOME=$2 ;; --xdg-data-home) export XDG_DATA_HOME=$2 ;;
        --xdg-state-home) export XDG_STATE_HOME=$2 ;; --xdg-cache-home) export XDG_CACHE_HOME=$2 ;;
        --xdg-bin-home) export XDG_BIN_HOME=$2 ;;
        --select|--wezterm-destination) choices+=("$1" "$2") ;;
        --adopt|--replace) approvals+=("$1" "$2") ;;
        --helper-adopt) helper_approvals+=(--adopt "$2") ;;
        --helper-replace) helper_approvals+=(--replace "$2") ;;
      esac
      shift 2 ;;
    *) fail "Unknown option: $1" ;;
  esac
done
if [[ -n $platform ]] || ! $setup || $machine; then
  case $platform in arch|void|macos|wsl) ;; *) fail 'Select a supported --platform.' ;; esac
fi
[[ $(id -u) != 0 ]] || fail 'Run as the intended user, not root; individual system changes use sudo.'
export USER=${USER:-$(id -un)}
[[ $USER == "$(id -un)" ]] || fail '--user must be the invoking user (do not provision through sudo).'
export HOME XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share} XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache} XDG_BIN_HOME=${XDG_BIN_HOME:-$HOME/.local/bin}
for path in "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_BIN_HOME" "$dotfiles" "$dotvim" "$dotshell"; do
  [[ $path == /* && $path != / && $path != *$'\n'* ]] || fail 'Supply absolute non-root HOME/XDG/checkout paths.'
done
export DOTSYS_REPO_HOME=$root
[[ -z $platform ]] || export DOTSYS_PLATFORM=$platform
# Legacy tool-only names must not hide a whole-machine/configuration install.
if $setup && ! $machine; then
  $want_config || $want_vim || $want_shell || fail 'Choose --dotfiles, --dotvim, --dotshell, or --dotsys PLATFORM.'
  source "$root/shared/helper-env.sh"
  [[ -f $dotfiles/setup/managed.py ]] || fail 'Prepare --dotfiles-root first; tool-only setup does not acquire/install dotfiles.'
  if $want_config; then
    bash "$dotfiles/setup/install" "${choices[@]}" "${approvals[@]}"
  elif [[ ${#choices[@]} != 0 || ${#approvals[@]} != 0 ]]; then
    fail 'Configuration choices/approvals require --dotfiles or the full handoff.'
  fi
  registration=(--dotfiles-root "$dotfiles" "${helper_approvals[@]}")
  if $want_vim; then
    helper_need git nvim
    bash "$root/shared/repositories.sh" acquire dotvim "$dotvim" "${DOTSYS_DOTVIM_SOURCE:-https://github.com/davelens/dotvim.git}"
    registration+=(--dotvim-root "$dotvim")
  fi
  if $want_shell; then
    helper_need git qs
    bash "$root/shared/repositories.sh" acquire dotshell "$dotshell" "${DOTSYS_DOTSHELL_SOURCE:-https://github.com/davelens/dotshell.git}"
    registration+=(--dotshell-root "$dotshell")
  fi
  if $want_vim || $want_shell; then bash "$root/shared/register-helpers" apply "${registration[@]}"; fi
  exit 0
fi
# Provider validation is before all package/configuration mutation.
case $platform in
  arch|wsl)
    [[ $(uname -s) == Linux ]] && command -v pacman >/dev/null && command -v systemctl >/dev/null || fail 'Arch/systemd provider required.'
    [[ $platform != arch || $(uname -m) == x86_64 ]] || fail 'Native Arch requires x86_64.'
    [[ $platform != wsl || $(uname -r) == *[Mm]icrosoft* ]] || fail 'WSL requires Arch WSL2 with systemd.'
    systemctl --system show --property=Version --value >/dev/null || fail 'Systemd must be enabled.' ;;
  void)
    command -v xbps-uhelper >/dev/null && [[ $(xbps-uhelper arch) == x86_64 ]] && command -v sv >/dev/null || fail 'Void x86_64 glibc/runit provider required.' ;;
  macos) [[ $(uname -s):$(uname -m) == Darwin:arm64 ]] || fail 'Apple Silicon macOS required.' ;;
esac
stage='bootstrap'
trap 'status=$?; printf "dotsys: failed during %s; completed changes preserved, dependent stages stopped.\n" "$stage" >&2; exit "$status"' ERR
case $platform in
  arch|wsl) bash "$root/arch/packages/init.sh" --bootstrap ;;
  void) bash "$root/void/packages/init.sh" --bootstrap ;;
  macos)
    bash "$root/shared/brew/init.sh" --skip-bundles
    export PATH="/opt/homebrew/bin:/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
    brew install bash python git coreutils gnu-sed tmux mise neovim git-delta gnupg ;;
esac
bash_bin=$(command -v bash)
"$bash_bin" --noprofile --norc -c '((BASH_VERSINFO[0] >= 5))' || fail 'Bootstrap did not supply Bash 5 on PATH.'
# Continue in the new Bash without re-running package bootstrap.
# No Bash-5-only syntax is needed by this small orchestrator itself.
export PATH="$XDG_BIN_HOME:${MISE_DATA_DIR:-$XDG_DATA_HOME/mise}/shims:$PATH"
"$bash_bin" "$root/shared/repositories.sh" acquire dotfiles "$dotfiles" "${DOTSYS_DOTFILES_SOURCE:-https://github.com/davelens/dotfiles.git}"
[[ -f $dotfiles/setup/common.sh ]] || fail 'dotfiles setup/common.sh is missing.'
# Resolve trusted choices with the completed dotfiles interface, in Bash 5.
# Export only the explicit handoff fields, never dump the private environment.
resolved=$("$bash_bin" --noprofile --norc -c '
  set -e
  source "$1/setup/common.sh"
  root=$1; shift
  dots_bootstrap install "$root/setup/install" "$@"
  for key in DOTS_SELECTION DOTS_WEZTERM_DESTINATION DOTS_SAVE HOME USER XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_BIN_HOME GNUPGHOME MISE_DATA_DIR PATH; do
    printf "export %s=%q\n" "$key" "${!key-}"
  done
' bash "$dotfiles" "${choices[@]}")
eval "$resolved"
export DOTFILES_REPO_HOME=$dotfiles DOTSYS_REPO_HOME=$root DOTSYS_PLATFORM=$platform
# Defaults for compatibility aliases do not override explicit empty/saved choices.
if [[ -n $default_selection && -z ${DOTS_INSTALL_SELECTION+x} && ! -e $XDG_CONFIG_HOME/dots/env ]]; then
  explicit=false
  for arg in "${choices[@]}"; do [[ $arg != --select ]] || explicit=true; done
  $explicit || DOTS_SELECTION=$default_selection
fi
export DOTS_INSTALL_SELECTION=$DOTS_SELECTION DOTS_INSTALL_WEZTERM_DESTINATION=$DOTS_WEZTERM_DESTINATION
check_args=(--select "$DOTS_SELECTION" --wezterm-destination "$DOTS_WEZTERM_DESTINATION")
install_args=("${check_args[@]}" "${approvals[@]}")
[[ $DOTS_SAVE != 1 ]] || install_args+=(--save)
selected() { [[ ,$DOTS_SELECTION, == *",$1,"* ]]; }
case $platform in
  arch|void) "$bash_bin" "$root/$platform/packages/init.sh" --selected "$DOTS_SELECTION" ;;
  macos)
    if selected macos-desktop; then
      brew install felixkratz/formulae/borders felixkratz/formulae/sketchybar
      brew install --cask ghostty nikitabobko/tap/aerospace
    fi
    if selected karabiner; then brew install --cask karabiner-elements; fi
    if selected alfred; then brew install --cask alfred; fi ;;
esac
stage='configuration prerequisites'
"$bash_bin" "$dotfiles/setup/check" prerequisites "${check_args[@]}"
stage='configuration install'
"$bash_bin" "$dotfiles/setup/install" "${install_args[@]}"
stage='runtime preparation'
"$bash_bin" "$root/shared/mise/init.sh" --config "$dotfiles/config/mise/config.toml"
stage='GnuPG preparation'
"$bash_bin" "$root/shared/gnupg/init.sh"
stage='external repositories'
"$bash_bin" "$root/shared/repositories.sh" acquire dotvim "$dotvim" "${DOTSYS_DOTVIM_SOURCE:-https://github.com/davelens/dotvim.git}"
registration=(--dotfiles-root "$dotfiles" --dotvim-root "$dotvim" "${helper_approvals[@]}")
if selected sway || $want_shell; then
  "$bash_bin" "$root/shared/repositories.sh" acquire dotshell "$dotshell" "${DOTSYS_DOTSHELL_SOURCE:-https://github.com/davelens/dotshell.git}"
  registration+=(--dotshell-root "$dotshell")
fi
if selected sway && [[ $platform == void ]]; then registration+=(--void-autotiling); fi
stage='helper registration'
"$bash_bin" "$root/shared/register-helpers" apply "${registration[@]}"
stage='service preparation'
export DOTSYS_DOTSHELL_ROOT=$dotshell
if selected sway; then
  for service in sway greetd kanshi; do "$bash_bin" "$root/$platform/init.d/$service.sh" --prepare; done
  if [[ $platform == void ]]; then
    "$bash_bin" "$root/void/init.d/turnstile.sh" --prepare
    "$bash_bin" "$root/void/init.d/pipewire.sh" --prepare
  fi
fi
stage='readiness'
"$bash_bin" "$dotfiles/setup/check" readiness "${check_args[@]}"
if $full; then
  stage='explicit full-machine workflow'
  case $platform in
    arch)
      "$root/arch/preflight.sh"
      for service in amdgpu-brightness wifi bluetooth kanata power-profiles; do "$root/arch/init.d/$service.sh"; done
      if selected sway; then "$root/arch/init.d/sway.sh" --extras; fi
      "$root/arch/misc.sh" ;;
    void) "$root/void/preflight.sh"; "$root/void/packages/init.sh"; if selected sway; then "$root/void/init.d/sway.sh" --extras; fi ;;
    macos|wsl)
      "$root/shared/brew/init.sh" --no-confirm
      "$root/shared/cargo/init.sh"
      echo 'GitHub extensions are explicit: shared/gh/init.sh (requires existing authentication).' ;;
  esac
fi
stage='activation'
if selected sway; then
  if [[ $platform == void ]]; then
    "$bash_bin" "$root/void/init.d/turnstile.sh" --activate
    "$bash_bin" "$root/void/init.d/pipewire.sh" --activate
  fi
  "$bash_bin" "$root/$platform/init.d/sway.sh" --activate
  "$bash_bin" "$root/$platform/init.d/kanshi.sh" --activate
  # Last: Void VT1 takeover can terminate this process.
  "$bash_bin" "$root/$platform/init.d/greetd.sh" --activate
fi
if selected macos-desktop; then
  brew services start borders
  brew services start sketchybar
  open -a AeroSpace
fi
printf 'dotsys: handoff complete; real-platform validation is separate.\n'
