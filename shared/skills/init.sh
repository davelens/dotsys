#!/usr/bin/env bash
set -euo pipefail

ME=${BASH_SOURCE[0]/\.\//}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_TXT="$SCRIPT_DIR/skills.txt"
AGENT_SKILLS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agents/skills"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude}"
SKILLS_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/skills"
SKILLS_LOCK="$SKILLS_STATE_DIR/.skills-lock.json"

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

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" == \#* ]] && continue

  # Parse skill name: 'owner/repo@skill-name' -> 'skill-name'
  skill_name="${line##*@}"

  if [[ -d "$AGENT_SKILLS_DIR/$skill_name" || -L "$AGENT_SKILLS_DIR/$skill_name" ]]; then
    echo "[$ME] - $skill_name already installed, skipping."
    continue
  fi

  echo "[$ME] - $line"
  npx skills add "$line" --yes >/dev/null 2>&1 </dev/null ||
    echo "[$ME] WARNING: Failed to install '$line'" >&2
done <"$SKILLS_TXT"

# ── Move freshly-installed skills to the central target ─────────
LOCAL_SKILLS_DIR="$SCRIPT_DIR/.agents/skills"
if [[ -d "$LOCAL_SKILLS_DIR" ]]; then
  echo "[$ME]"
  echo "[$ME] Moving installed skills to $AGENT_SKILLS_DIR"
  for skill_dir in "$LOCAL_SKILLS_DIR"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_dir="${skill_dir%/}"
    skill_name="$(basename "$skill_dir")"
    target="$AGENT_SKILLS_DIR/$skill_name"
    if [[ -e "$target" || -L "$target" ]]; then
      echo "[$ME] $skill_name already exists in target, skipping move."
      continue
    fi
    mv "$skill_dir" "$target"
    echo "[$ME] - $skill_name -> $target"
  done
fi

# ── Persist skills-lock.json to state dir ───────────────────────
if [[ -f "$SCRIPT_DIR/skills-lock.json" ]]; then
  mv -f "$SCRIPT_DIR/skills-lock.json" "$SKILLS_LOCK"
fi

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
