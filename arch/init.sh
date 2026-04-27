#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$DOTSYS_REPO_HOME/arch/preflight.sh"
"$DOTSYS_REPO_HOME/arch/init.d/wifi.sh"
"$DOTSYS_REPO_HOME/arch/init.d/bluetooth.sh"
"$DOTSYS_REPO_HOME/arch/init.d/sway.sh"
"$DOTSYS_REPO_HOME/arch/init.d/greetd.sh"
"$DOTSYS_REPO_HOME/arch/init.d/kanshi.sh"
"$DOTSYS_REPO_HOME/arch/init.d/kanata.sh"
"$DOTSYS_REPO_HOME/arch/init.d/power-profiles.sh"
"$DOTSYS_REPO_HOME/shared/gnupg/init.sh"
"$DOTSYS_REPO_HOME/shared/skills/init.sh"

# These are disabled because I either don't need them by default anymore,
# or I want to install them delayed because they eat up too much time.
# "$DOTSYS_REPO_HOME/shared/mise/init.sh"
# "$DOTSYS_REPO_HOME/shared/cargo/init.sh"
# "$DOTSYS_REPO_HOME/arch/init.d/mariadb.sh"
# "$DOTSYS_REPO_HOME/arch/init.d/postgres.sh"
# "$DOTSYS_REPO_HOME/arch/packages/init.sh" --update
# "$DOTSYS_REPO_HOME/arch/init.d/waybar.sh"
# "$DOTSYS_REPO_HOME/shared/gh/init.sh"

# NOTE: This is disabled for now until I can properly "reset" this to
# the default state of things. It should by-and-large work though.
# "$DOTSYS_REPO_HOME/arch/init.d/fingerprint-auth.sh"
