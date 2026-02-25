#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[validate] root: $ROOT"

required_files=(
  "README.md"
  "workflow.md"
  "mobile-gitlab-standard.md"
  "skills-map.md"
  "scripts/install_skills.sh"
  "scripts/notify_google_chat.sh"
  "scripts/bootstrap_playbook_setup.sh"
  "scripts/update_playbook_setup.sh"
  "scripts/preflight_pipeline_runner.sh"
  "scripts/generate_run_summary.sh"
  "templates/playbook.config.template.yml"
  "templates/run-summary.template.md"
  "skills/pipeline-runner/SKILL.md"
  "skills/playbook-setup/SKILL.md"
)

for f in "${required_files[@]}"; do
  if [[ ! -f "$ROOT/$f" ]]; then
    echo "[validate][error] missing file: $f" >&2
    exit 1
  fi
done

echo "[validate] required files: ok"

echo "[validate] shell syntax..."
while IFS= read -r sh_file; do
  bash -n "$sh_file"
done < <(find "$ROOT/scripts" -type f -name '*.sh' | sort)
echo "[validate] shell syntax: ok"

echo "[validate] contract consistency..."
rg -n "RUN_MODE: REAL_RUN\\|DRY_RUN\\|PLAN_ONLY" "$ROOT/README.md" "$ROOT/workflow.md" "$ROOT/skills/pipeline-runner/SKILL.md" >/dev/null
rg -n "playbook-setup" "$ROOT/README.md" "$ROOT/workflow.md" "$ROOT/skills-map.md" >/dev/null
rg -n "run_summary\\.md" "$ROOT/README.md" "$ROOT/workflow.md" "$ROOT/skills/pipeline-runner/SKILL.md" >/dev/null
echo "[validate] contract consistency: ok"

echo "[validate] done"
