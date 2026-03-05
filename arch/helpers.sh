# Only declare functions once.
declare -F read_packages &>/dev/null && return 0

read_packages() {
	grep -v '^\s*#' "$1" | grep -v '^\s*$' | awk '{print $1}'
}
