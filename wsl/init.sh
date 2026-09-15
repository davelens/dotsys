#!/usr/bin/env bash
set -e
root=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
exec bash "$root/shared/install.sh" --platform wsl "$@"
