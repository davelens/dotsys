#!/usr/bin/env bash
set -euo pipefail
# Configuration owns this directory. Do not start an agent or import identities.
[[ ${GNUPGHOME:-} == /* && -d $GNUPGHOME && ! -L $GNUPGHOME ]] || {
  echo 'dotsys: GNUPGHOME must already be a configured directory; install dotfiles first.' >&2
  exit 1
}
chmod 700 "$GNUPGHOME"
gpg --batch --no-autostart --homedir "$GNUPGHOME" --list-keys >/dev/null
