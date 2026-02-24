#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/skills"
DEST="${HOME}/.codex/skills"

if [[ ! -d "$SRC" ]]; then
  echo "skills directory not found at: $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"

for skill_dir in "$SRC"/*; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"
  [[ "$skill_name" == "README.md" ]] && continue

  if [[ -f "$skill_dir/SKILL.md" ]]; then
    rm -rf "$DEST/$skill_name"
    cp -R "$skill_dir" "$DEST/$skill_name"
    echo "Installed skill: $skill_name"
  fi
done

echo "Done. Restart Codex Desktop to reload skills."
