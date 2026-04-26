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

# Download and build ggerganov/llama.cpp and run the server like so:
#
# ./ggerganov/llama.cpp/build/bin/llama-server \
#   -m ~/Documents/models/qwen/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf \
#   --alias qwen \
#   -ngl 999 \
#   -c 262144 \
#   -b 256 \
#   --chat-template-file ./ggerganov/llama.cpp/models/templates/Qwen-Qwen3-0.6B.jinja \
#   --temp 0.2 \
#   --top-p 0.9 \
#   --repeat-penalty 1.1 \
#   --mlock --mmap \
#   --host 0.0.0.0 \
#   --port 8080
#
# Host on 0.0.0.0 to make it accessible on my Tailscale network.
