#!/usr/bin/env bash
set -e
DOTSYS_REPO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

echo "==> Setting up llama.cpp with Gemma4 26B..."

sudo pacman -S --needed --noconfirm \
	git cmake ninja python python-huggingface-hub \
	vulkan-tools shaderc

sudo useradd --system --create-home --home-dir /var/lib/llama.cpp \
	--shell /usr/bin/nologin llama-cpp || true

sudo usermod -aG render,video llama-cpp

"$DOTSYS_REPO_HOME/arch/bin/llama-cpp-build"
"$DOTSYS_REPO_HOME/arch/bin/llama-cpp-fetch-gemma4"

sudo mkdir -p /etc/llama-cpp
sudo cp "$DOTSYS_REPO_HOME/arch/systemd/llama-cpp-gemma4.env" /etc/llama-cpp/gemma4.env
sudo cp "$DOTSYS_REPO_HOME/arch/systemd/llama-cpp-gemma4.service" /etc/systemd/system/llama-cpp-gemma4.service

sudo systemctl daemon-reload
sudo systemctl enable --now llama-cpp-gemma4.service

echo "==> llama.cpp Gemma4 service is running on port 11434."
