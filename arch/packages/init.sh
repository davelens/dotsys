#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

# The portability baseline is deliberately separate from the personal wishlist.
case ${1:-} in
  --bootstrap)
    sudo pacman -S --needed --noconfirm bash python git coreutils sed tmux mise neovim git-delta gnupg base-devel curl tar unzip
    exit ;;
  --selected)
    [[ $# == 2 ]] || exit 1
    if [[ ,$2, == *,sway,* ]]; then
      "$DOTSYS_REPO_HOME/arch/preflight.sh" --aur
      "$DOTSYS_REPO_HOME/arch/init.d/sway.sh" --packages
    fi
    exit ;;
esac

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
