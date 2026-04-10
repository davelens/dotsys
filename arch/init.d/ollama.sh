#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Ollama provisioning was replaced by llama.cpp. Delegating to llama-cpp.sh..."
exec "$DOTSYS_REPO_HOME/arch/init.d/llama-cpp.sh"
