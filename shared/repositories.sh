#!/usr/bin/env bash
set -euo pipefail
# The generated dvim/autotiling registrations link here, not to legacy installers.
case ${0##*/} in
  dvim)
    export NVIM_APPNAME="${NVIM_APPNAME:-dvim}"
    exec nvim -u "${XDG_CONFIG_HOME:-$HOME/.config}/dvim/init.lua" "$@" ;;
  autotiling-rs) exec autotiling "$@" ;;
esac

[[ $# -ge 3 && $1 == acquire ]] || {
  echo 'Usage: repositories.sh acquire dotfiles|dotvim|dotshell ABS_DEST [SOURCE]' >&2; exit 1;
}
name=$2 destination=$3 source=${4:-https://github.com/davelens/$2.git}
case $name in dotfiles|dotvim|dotshell) ;; *) exit 1 ;; esac
[[ $# -le 4 && $destination == /* && ! -L $destination ]] || {
  echo 'Repository destination must be an absolute non-symlink path.' >&2; exit 1;
}
# Public known origins, or an explicitly supplied local Git fixture/checkout.
if [[ $source != "https://github.com/davelens/$name.git" ]]; then
  [[ $source == /* && -d $source ]] && git -C "$source" rev-parse --git-dir >/dev/null || {
    echo 'Unverified repository origin; supply the known public origin or an explicit local Git source.' >&2; exit 1;
  }
fi
if [[ -e $destination ]]; then
  [[ -d $destination && $(git -C "$destination" rev-parse --show-toplevel) == "$destination" ]] || {
    echo 'Existing destination is not the requested checkout; preserved.' >&2; exit 1;
  }
  [[ $(git -C "$destination" remote get-url origin) == "$source" ]] || {
    echo 'Existing checkout has a different origin; preserved. Supply its explicit local source if intended.' >&2; exit 1;
  }
else
  mkdir -p "${destination%/*}"
  git clone -- "$source" "$destination"
fi
# No fetch/pull/reset of existing checkouts. Only missing pinned submodules may
# be acquired; refuse mismatches/dirty submodules rather than moving them.
status=$(git -C "$destination" submodule status --recursive)
[[ $status != *$'\n+'* && $status != +* && $status != U* && $status != *$'\nU'* ]] || {
  echo 'Submodule revision mismatch; prepare it explicitly without overwriting local work.' >&2; exit 1;
}
if [[ $status == -* || $status == *$'\n-'* ]]; then
  git -C "$destination" submodule update --init --recursive
fi
