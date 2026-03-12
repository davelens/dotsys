#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Setting up Ollama with ROCm GPU support..."

sudo pacman -S --needed --noconfirm ollama ollama-rocm

# The ollama user needs render and video group access for the AMD dGPU.
sudo usermod -aG render,video ollama

# Install systemd override to configure GPU targeting and context window.
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo cp "$DOTSYS_REPO_HOME/arch/systemd/ollama.service.d/override.conf" \
	/etc/systemd/system/ollama.service.d/override.conf

sudo systemctl daemon-reload
sudo systemctl enable ollama.service
sudo systemctl restart ollama

echo "==> Ollama is running with ROCm on the dGPU."
