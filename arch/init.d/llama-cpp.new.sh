#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Setting up llama.cpp with Gemma4 31B..."

sudo pacman -Syu vulkan-devel vulkan-icd-loader vulkan-tools
sudo pacman -S mesa vulkan-radeon
sudo pacman -S python-pipx

pipx install huggingface_hub
# Optional downloads commented out because they need a login ideally.
# hf auth login # Should put HUGGINGFACE_TOKEN into ~/.config/dots/env
# hf download unsloth/gemma-4-31B-it-GGUF gemma-4-31B-it-Q4_K_M.gguf
# hf download qwen/Qwen3.6-35B-A3B

git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
rm -rf build
cmake -B build -DGGML_VULKAN=ON
cmake --build build -j --target llama-server llama-cli
