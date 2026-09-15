#!/usr/bin/env bash
set -euo pipefail
# Tools-only preparation also works on a retained, rejected update candidate.
# Verified against mise 2026.8.6: config get --file, install TOOL@VERSION.
[[ $# == 2 && $1 == --config && $2 == /* && -f $2 ]] || {
  echo 'Usage: shared/mise/init.sh --config /absolute/config.toml' >&2; exit 1;
}
[[ ${HOME:-} == /* ]] || { echo 'Set an absolute HOME.' >&2; exit 1; }
config=$2
command -v mise >/dev/null
command -v python3 >/dev/null
# Do not discover active/project configs, trust a candidate, or execute its hooks.
export MISE_NO_CONFIG=1 MISE_NO_ENV=1 MISE_NO_HOOKS=1 MISE_AUTO_UPDATE=0
export MISE_GLOBAL_CONFIG_FILE=/dev/null MISE_SYSTEM_CONFIG_FILE=/dev/null
export MISE_CONFIG_DIR=/dev/null
cd "$HOME"
declarations=$(mise config get tools --file "$config")
requests=$(python3 -I -B -c '
import re, sys
lines = [v for v in sys.stdin.read().splitlines() if v.strip()]
if not lines: sys.exit("No declared mise tools")
for line in lines:
    m = re.fullmatch(r"([a-zA-Z0-9_-]+) = \"(latest|[0-9]+(?:\.[0-9]+){2})\"", line)
    if not m: sys.exit("Unsupported mise declaration; expected string pins/latest")
    print(m[1] + "@" + m[2])
' <<< "$declarations")
# Bash 3.2 compatible; Bash itself is supplied by native bootstrap, not mise.
tools=()
while IFS= read -r tool; do tools+=("$tool"); done <<< "$requests"
mise install --yes "${tools[@]}"
