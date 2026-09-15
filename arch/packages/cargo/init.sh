#!/usr/bin/env bash
set -e
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
exec bash "$root/shared/cargo/init.sh" "$@"
