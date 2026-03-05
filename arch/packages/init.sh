#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

usage() {
	echo "Usage: $(basename "$0") [OPTIONS]"
	echo
	echo "Install all packages from dotfiles package lists."
	echo
	echo "Options:"
	echo "  --update    Pull in packages updates before installing"
	exit 0
}

main() {
	UPDATE=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--update)
			UPDATE=true
			shift
			;;
		-h | --help)
			usage
			;;
		*)
			usage
			;;
		esac
	done

	if [[ "$UPDATE" == true ]]; then
		paru -Syu --noconfirm
		flatpak update -y
	fi

	"$DOTSYS_REPO_HOME/arch/bin/pacman" --install-from-file "$DOTSYS_REPO_HOME/arch/packages/pacman.txt"
	"$DOTSYS_REPO_HOME/arch/bin/paru" --install-from-file "$DOTSYS_REPO_HOME/arch/packages/aur.txt"
	"$DOTSYS_REPO_HOME/arch/bin/flatpak" --install-from-file "$DOTSYS_REPO_HOME/arch/packages/flatpak.txt"
}

main "$@"
