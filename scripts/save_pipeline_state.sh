#!/usr/bin/env bash
set -euo pipefail

# save_pipeline_state.sh — Persist pipeline execution state to disk.
#
# Writes a pipeline_state.json to <ARTIFACTS_PATH>/<JIRA_KEY>/pipeline_state.json
# so a pipeline can be resumed if the chat session is interrupted.
#
# Usage:
#   bash scripts/save_pipeline_state.sh \
#     --repo        <absolute-path>            \
#     --jira-key    <KEY-123>                  \
#     --run-mode    <REAL_RUN|DRY_RUN|PLAN_ONLY> \
#     --step        <current-step-name>        \
#     --status      <in_progress|completed|blocked> \
#     [--working-branch <branch>]              \
#     [--artifacts-path <path>]                \
#     [--completed-steps <comma-separated>]    \
#     [--notes <text>]

usage() {
  cat <<'EOF'
Usage: bash scripts/save_pipeline_state.sh --repo <path> --jira-key <KEY> --run-mode <MODE> --step <step> --status <status> [options]
EOF
}

REPO_PATH=""
JIRA_KEY=""
RUN_MODE=""
CURRENT_STEP=""
STATUS=""
WORKING_BRANCH=""
ARTIFACTS_PATH=""
COMPLETED_STEPS=""
NOTES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)             REPO_PATH="${2:-}"; shift 2 ;;
    --jira-key)         JIRA_KEY="${2:-}"; shift 2 ;;
    --run-mode)         RUN_MODE="${2:-}"; shift 2 ;;
    --step)             CURRENT_STEP="${2:-}"; shift 2 ;;
    --status)           STATUS="${2:-}"; shift 2 ;;
    --working-branch)   WORKING_BRANCH="${2:-}"; shift 2 ;;
    --artifacts-path)   ARTIFACTS_PATH="${2:-}"; shift 2 ;;
    --completed-steps)  COMPLETED_STEPS="${2:-}"; shift 2 ;;
    --notes)            NOTES="${2:-}"; shift 2 ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$REPO_PATH" ]]      || { echo "ERROR: --repo is required" >&2; exit 2; }
[[ -n "$JIRA_KEY" ]]       || { echo "ERROR: --jira-key is required" >&2; exit 2; }
[[ -n "$RUN_MODE" ]]       || { echo "ERROR: --run-mode is required" >&2; exit 2; }
[[ -n "$CURRENT_STEP" ]]   || { echo "ERROR: --step is required" >&2; exit 2; }
[[ -n "$STATUS" ]]         || { echo "ERROR: --status is required" >&2; exit 2; }

# Resolve output dir
if [[ -z "$ARTIFACTS_PATH" ]]; then
  ARTIFACTS_PATH="$REPO_PATH/.playbook/pipeline-runner"
fi

STATE_DIR="$ARTIFACTS_PATH/$JIRA_KEY"
mkdir -p "$STATE_DIR"

# Detect current git branch if not provided
if [[ -z "$WORKING_BRANCH" ]]; then
  WORKING_BRANCH="$(git -C "$REPO_PATH" branch --show-current 2>/dev/null || echo 'unknown')"
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

python3 - "$STATE_DIR/pipeline_state.json" \
  "$JIRA_KEY" "$RUN_MODE" "$CURRENT_STEP" "$STATUS" \
  "$WORKING_BRANCH" "$COMPLETED_STEPS" "$NOTES" "$TIMESTAMP" << 'PY'
import json, sys, os

out_path, jira_key, run_mode, current_step, status, \
  working_branch, completed_steps_raw, notes, timestamp = sys.argv[1:]

completed = [s.strip() for s in completed_steps_raw.split(",") if s.strip()] \
  if completed_steps_raw else []

# Merge with existing state if present
existing = {}
if os.path.exists(out_path):
  try:
    with open(out_path) as f:
      existing = json.load(f)
  except Exception:
    pass

# Build history entry
history = existing.get("history", [])
history.append({
  "step": current_step,
  "status": status,
  "timestamp": timestamp,
})

state = {
  "schema_version": 1,
  "jira_key": jira_key,
  "run_mode": run_mode,
  "working_branch": working_branch,
  "current_step": current_step,
  "status": status,
  "completed_steps": completed if completed else existing.get("completed_steps", []),
  "notes": notes or existing.get("notes", ""),
  "updated_at": timestamp,
  "created_at": existing.get("created_at", timestamp),
  "history": history,
}

with open(out_path, "w") as f:
  json.dump(state, f, indent=2, ensure_ascii=False)
  f.write("\n")

print(f"Pipeline state saved: {out_path}")
PY
