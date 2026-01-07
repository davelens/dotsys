#!/usr/bin/env bash
set -e

DOTSYS_REPO_HOME="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
export DOTSYS_REPO_HOME

"$DOTSYS_REPO_HOME/arch/preflight.sh"
"$DOTSYS_REPO_HOME/shared/gnupg/init.sh"
"$DOTSYS_REPO_HOME/shared/mise/init.sh"
"$DOTSYS_REPO_HOME/shared/cargo/init.sh"
"$DOTSYS_REPO_HOME/arch/init.d/sway.sh"
"$DOTSYS_REPO_HOME/arch/init.d/waybar.sh"
"$DOTSYS_REPO_HOME/arch/init.d/power-profiles.sh"
"$DOTSYS_REPO_HOME/arch/init.d/fingerprint-auth.sh"
"$DOTSYS_REPO_HOME/arch/init.d/alt-tab.sh"

utility arch bundle --update
"$DOTSYS_REPO_HOME/arch/init.d/kanata.sh"
"$DOTSYS_REPO_HOME/arch/init.d/albert.sh"
"$DOTSYS_REPO_HOME/arch/init.d/mariadb.sh"
