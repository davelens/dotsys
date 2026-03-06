#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
source "$DOTSYS_REPO_HOME/arch/helpers.sh"

main() {
	if ! command -v gh &>/dev/null; then
		echo "Error: gh is not available. GitHub CLI may not be installed correctly."
		exit 1
	fi

	local extensions
	mapfile -t extensions < <(read_packages "$DOTSYS_REPO_HOME/shared/gh/extensions")

	echo "==> Installing gh extensions..."
	for ext in "${extensions[@]}"; do
		echo "    Installing $ext..."
		gh extension install "$ext" 2>/dev/null || gh extension upgrade "$ext"
	done
	echo "==> gh extensions installed successfully."
}

main "$@"
