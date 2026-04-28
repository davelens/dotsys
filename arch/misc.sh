#!/usr/bin/env bash
set -e

# `xdg-settings` is provided by xdg-utils; already installed via archinstall.json.
xdg-settings set default-web-browser firefox.desktop
