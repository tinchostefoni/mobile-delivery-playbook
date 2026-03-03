#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/skills"
DEST="${HOME}/.playbook/skills"
RUNTIME_NAME=".mobile-delivery-playbook-runtime"
RUNTIME_DEST="$DEST/$RUNTIME_NAME"

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

rm -rf "$RUNTIME_DEST"
mkdir -p "$RUNTIME_DEST"

cp -R "$REPO_ROOT/scripts" "$RUNTIME_DEST/scripts"
cp -R "$REPO_ROOT/contracts" "$RUNTIME_DEST/contracts"
cp -R "$REPO_ROOT/templates" "$RUNTIME_DEST/templates"
cp "$REPO_ROOT/workflow.md" "$RUNTIME_DEST/workflow.md"
cp "$REPO_ROOT/technical-reference.md" "$RUNTIME_DEST/technical-reference.md"

echo "Installed shared playbook runtime: $RUNTIME_DEST"

echo "Done. Restart Claude Code to reload skills."
