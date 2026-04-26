#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO_HOME:-$HOME/Repositories/davelens/dotfiles}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_TXT="$SCRIPT_DIR/skills.txt"
AGENT_SKILLS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agents/skills"

# ── Check for npx ───────────────────────────────────────────────
if ! command -v npx &>/dev/null; then
    echo "[init] npx not found. Installing..."
    if command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm nodejs 2>/dev/null || true
    elif command -v apt &>/dev/null; then
        sudo apt install -y nodejs npm 2>/dev/null || true
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y nodejs npm 2>/dev/null || true
    elif command -v apk &>/dev/null; then
        sudo apk add --no-cache nodejs npm 2>/dev/null || true
    else
        echo "[init] ERROR: Cannot detect package manager. Please install Node.js/npm manually." >&2
        exit 1
    fi
    if ! command -v npx &>/dev/null; then
        echo "[init] ERROR: Failed to install npx. Please install Node.js/npm manually." >&2
        exit 1
    fi
    echo "[init] npx installed successfully."
fi

# ── Ensure target directory exists ──────────────────────────────
mkdir -p "$AGENT_SKILLS_DIR"

# ── Install skills from skills.txt ──────────────────────────────
echo "[init] Installing skills from $SKILLS_TXT ..."
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue
    echo "[init] Installing: $line"
    npx skills add -g $line --yes </dev/null 2>&1 || echo "[init] WARNING: Failed to install '$line'" >&2
done < "$SKILLS_TXT"

# ── Symlink dotfiles agent-skills ───────────────────────────────
DOTFILES_SKILLS_DIR="$DOTFILES_REPO/config/agent-skills"
if [[ -d "$DOTFILES_SKILLS_DIR" ]]; then
    echo "[init] Symlinking skills from $DOTFILES_SKILLS_DIR ..."
    for skill_dir in "$DOTFILES_SKILLS_DIR"/*/; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"
        target="$AGENT_SKILLS_DIR/$skill_name"
        if [[ -L "$target" ]]; then
            echo "[init] $skill_name already symlinked, skipping."
        elif [[ -d "$target" ]]; then
            echo "[init] $skill_name already exists as directory, skipping."
        else
            ln -s "$skill_dir" "$target"
            echo "[init] Symlinked $skill_name -> $skill_dir"
        fi
    done
else
    echo "[init] No agent-skills directory found at $DOTFILES_SKILLS_DIR, skipping symlinks."
fi

echo "[init] Done."
