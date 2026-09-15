# Shared only by the existing provisioning scripts, not shell startup.
read_packages() {
  awk '!/^[[:space:]]*#/ && NF {print $1}' "$1"
}

# Keep prepared service files outside monitored directories. Existing definitions
# are immutable here: a changed definition needs explicit manual reconciliation.
service_context() {
  source "$DOTSYS_REPO_HOME/shared/helper-env.sh"
  phase=${1:---all}
  case $phase in --all|--packages|--prepare|--activate|--extras) ;; *) helper_fail 'Use --packages, --prepare, or --activate.' ;; esac
  prepared="$XDG_STATE_HOME/dotsys/prepared"
  if [[ $phase != --packages ]]; then mkdir -p "$prepared"; fi
}
# A system greeter must not assume the environment of the provisioning shell.
# Limit explicit paths to this user; other login accounts keep native defaults.
session_exports() {
  python3 -I -B -c '
import os, shlex, sys
print("#!/bin/sh")
print("if [ \"$(id -u)\" = " + shlex.quote(sys.argv[1]) + " ]; then")
for key in ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_BIN_HOME"):
    print("  export " + key + "=" + shlex.quote(os.environ[key]))
print("fi")
print("export PATH=\"${XDG_BIN_HOME:-$HOME/.local/bin}:${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH\"")
' "$(id -u)"
}
service_file() {
  local target=$1 mode=${2:-644} temp
  mkdir -p "${target%/*}"
  temp=$(mktemp "$prepared/.definition.XXXXXX")
  cat >"$temp"
  chmod "$mode" "$temp"
  if [[ -e $target || -L $target ]]; then
    if [[ -L $target ]] || ! cmp -s "$temp" "$target"; then
      rm "$temp"
      helper_fail "Prepared definition differs: $target; reconcile explicitly (no active state was changed)."
    fi
  else
    ln "$temp" "$target" || { rm "$temp"; return 1; }
  fi
  rm "$temp"
}
service_link() {
  local source=$1 target=$2
  if [[ -e $target || -L $target ]]; then
    [[ -L $target && $(readlink "$target") == "$source" ]] || helper_fail "Service destination conflict: $target"
  else
    mkdir -p "${target%/*}"
    ln -sT "$source" "$target"
  fi
}
