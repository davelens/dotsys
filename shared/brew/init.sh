#!/usr/bin/env bash
set -e

if command -v brew &>/dev/null; then
	echo "Homebrew is already installed."
	brew update
else
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
