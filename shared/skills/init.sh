#!/usr/bin/env bash
set -euo pipefail

ME=${BASH_SOURCE[0]/\.\//}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_TXT="$SCRIPT_DIR/skills.txt"
AGENT_SKILLS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agents/skills"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude}"
SKILLS_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SKILLS_STATE_DIR="$SKILLS_STATE_HOME/skills"

# ── Check that node is installed via mise ───────────────────────
if ! command -v mise &>/dev/null; then
  echo "[$ME] ERROR: mise not found. Install mise first." >&2
  exit 1
fi

if ! mise which node &>/dev/null; then
  echo "[$ME] ERROR: node is not installed via mise. Run 'mise use -g node@lts' first." >&2
  exit 1
fi

if ! command -v npx &>/dev/null; then
  echo "[$ME] ERROR: npx not found on PATH (expected via mise-installed node)." >&2
  exit 1
fi

# ── Install skills from skills.txt ──────────────────────────────
echo "[$ME] Installing skills from skills.txt"
mkdir -p "$AGENT_SKILLS_DIR" "$SKILLS_STATE_DIR"
cd "$SCRIPT_DIR"

TMP_SKILLS_HOME="$(mktemp -d)"
cleanup_tmp_skills_home() {
  rm -rf "$TMP_SKILLS_HOME"
}
trap cleanup_tmp_skills_home EXIT

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" == \#* ]] && continue

  # Parse skill name: 'owner/repo@skill-name' -> 'skill-name'
  skill_name="${line##*@}"

  echo "[$ME] - $line"
  if ! HOME="$TMP_SKILLS_HOME" XDG_STATE_HOME="$SKILLS_STATE_HOME" npx skills add "$line" -g -a universal --yes >/dev/null 2>&1 </dev/null; then
    echo "[$ME] WARNING: Failed to install '$line'" >&2
    continue
  fi

  installed_skill_dir="$TMP_SKILLS_HOME/.agents/skills/$skill_name"
  target="$AGENT_SKILLS_DIR/$skill_name"
  if [[ -e "$target" || -L "$target" ]]; then
    echo "[$ME] - $skill_name already installed, skipping move."
  elif [[ -d "$installed_skill_dir" ]]; then
    mv "$installed_skill_dir" "$target"
    echo "[$ME] - $skill_name -> $target"
  else
    echo "[$ME] WARNING: Installed skill '$skill_name' was not found at $installed_skill_dir" >&2
  fi
done <"$SKILLS_TXT"

# ── Clean up local install artifacts ────────────────────────────
rm -rf "$SCRIPT_DIR/.agents" "$SCRIPT_DIR/.claude"

# ── Symlink personal skills ─────────────────────────────────────
echo "[$ME]"
echo "[$ME] Symlinking personal skills"

PERSONAL_SKILLS_DIR="$SCRIPT_DIR/personal"
if [[ -d "$PERSONAL_SKILLS_DIR" ]]; then
  for skill_dir in "$PERSONAL_SKILLS_DIR"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_dir="${skill_dir%/}"
    skill_name="$(basename "$skill_dir")"
    target="$AGENT_SKILLS_DIR/$skill_name"
    if [[ -L "$target" && -e "$target" ]]; then
      echo "[$ME] - $skill_name already symlinked, skipping."
    elif [[ -d "$target" && ! -L "$target" ]]; then
      echo "[$ME] - $skill_name already exists as directory, skipping."
    else
      ln -sfn "$skill_dir" "$target"
      echo "[$ME] - Symlinked $skill_name -> $skill_dir"
    fi
  done
else
  echo "[$ME] No personal skills directory found at $PERSONAL_SKILLS_DIR, skipping symlinks."
fi

# ── Symlink skills utilities to dotfiles ────────────────────────
echo "[$ME]"
echo "[$ME] Symlinking binaries to dotfiles to enable \`u skills\`"

SKILLS_BIN_DIR="$SCRIPT_DIR/bin"
DOTFILES_UTILITIES_DIR="${DOTFILES_REPO_HOME:-$HOME/Repositories/davelens/dotfiles}/bin/utilities"
DOTFILES_SKILLS_UTILITY="$DOTFILES_UTILITIES_DIR/skills"

if [[ -d "$SKILLS_BIN_DIR" ]]; then
  mkdir -p "$DOTFILES_UTILITIES_DIR"
  ln -sfn "$SKILLS_BIN_DIR" "$DOTFILES_SKILLS_UTILITY"
  echo "[$ME] - skills -> $SKILLS_BIN_DIR"
else
  echo "[$ME] No skills bin directory found at $SKILLS_BIN_DIR, skipping utility symlink."
fi

# ── Expose centralized skills to Claude Code ────────────────────

if [[ -d "$CLAUDE_CONFIG_DIR" || -L "$CLAUDE_CONFIG_DIR" ]]; then
  CLAUDE_SKILLS_DIR="$CLAUDE_CONFIG_DIR/skills"

  echo "[$ME]"
  echo "[$ME] Claude installed; symlinking skills to $CLAUDE_SKILLS_DIR"

  if [[ -L "$CLAUDE_SKILLS_DIR" ]]; then
    ln -sfn "$AGENT_SKILLS_DIR" "$CLAUDE_SKILLS_DIR"
  elif [[ -e "$CLAUDE_SKILLS_DIR" ]]; then
    can_replace=true
    for entry in "$CLAUDE_SKILLS_DIR"/* "$CLAUDE_SKILLS_DIR"/.[!.]* "$CLAUDE_SKILLS_DIR"/..?*; do
      [[ -e "$entry" || -L "$entry" ]] || continue
      if [[ ! -L "$entry" ]]; then
        can_replace=false
        break
      fi
    done

    if [[ "$can_replace" == true ]]; then
      for entry in "$CLAUDE_SKILLS_DIR"/* "$CLAUDE_SKILLS_DIR"/.[!.]* "$CLAUDE_SKILLS_DIR"/..?*; do
        [[ -e "$entry" || -L "$entry" ]] || continue
        unlink "$entry"
      done
      rmdir "$CLAUDE_SKILLS_DIR"
      ln -s "$AGENT_SKILLS_DIR" "$CLAUDE_SKILLS_DIR"
    else
      echo "[$ME] Claude skills directory exists at $CLAUDE_SKILLS_DIR, leaving it unchanged."
    fi
  else
    ln -s "$AGENT_SKILLS_DIR" "$CLAUDE_SKILLS_DIR"
  fi
else
  echo "[$ME] Claude config directory not found at $CLAUDE_CONFIG_DIR, skipping."
fi

echo "[$ME]"
echo "[$ME] Done."
