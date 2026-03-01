# Only declare functions once.
command_exists 'read_packages' && return 0

DOTSYS_REPO_HOME="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_REPO_HOME="${DOTFILES_REPO_HOME:-$HOME/Repositories/davelens/dotfiles}"
export DOTSYS_REPO_HOME DOTFILES_REPO_HOME

read_packages() {
  grep -v '^\s*#' "$1" | grep -v '^\s*$' | awk '{print $1}'
}
