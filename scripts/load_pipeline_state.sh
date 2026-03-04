#!/usr/bin/env bash
set -euo pipefail

# load_pipeline_state.sh — Load and display saved pipeline state.
#
# Reads pipeline_state.json for the given JIRA_KEY and outputs it in
# text or JSON format so Claude can resume an interrupted pipeline.
#
# Usage:
#   bash scripts/load_pipeline_state.sh \
#     --repo        <absolute-path> \
#     --jira-key    <KEY-123>       \
#     [--artifacts-path <path>]     \
#     [--output-format text|json]
#
# Exit codes: 0=found, 1=not found

usage() {
  cat <<'EOF'
Usage: bash scripts/load_pipeline_state.sh --repo <path> --jira-key <KEY> [--output-format text|json]
EOF
}

REPO_PATH=""
JIRA_KEY=""
ARTIFACTS_PATH=""
OUTPUT_FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)             REPO_PATH="${2:-}"; shift 2 ;;
    --jira-key)         JIRA_KEY="${2:-}"; shift 2 ;;
    --artifacts-path)   ARTIFACTS_PATH="${2:-}"; shift 2 ;;
    --output-format)    OUTPUT_FORMAT="${2:-}"; shift 2 ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$REPO_PATH" ]]  || { echo "ERROR: --repo is required" >&2; exit 2; }
[[ -n "$JIRA_KEY" ]]   || { echo "ERROR: --jira-key is required" >&2; exit 2; }

if [[ -z "$ARTIFACTS_PATH" ]]; then
  ARTIFACTS_PATH="$REPO_PATH/.playbook/pipeline-runner"
fi

STATE_FILE="$ARTIFACTS_PATH/$JIRA_KEY/pipeline_state.json"

if [[ ! -f "$STATE_FILE" ]]; then
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo '{"found": false, "message": "No saved state found for '"$JIRA_KEY"'"}'
  else
    echo "STATE_NOT_FOUND: No saved pipeline state for $JIRA_KEY"
  fi
  exit 1
fi

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  python3 -c "
import json, sys
with open(sys.argv[1]) as f:
  state = json.load(f)
state['found'] = True
print(json.dumps(state, indent=2))
" "$STATE_FILE"
else
  python3 -c "
import json, sys
with open(sys.argv[1]) as f:
  s = json.load(f)
print(f\"STATE_FOUND: {s['jira_key']} | run_mode={s['run_mode']} | branch={s['working_branch']}\")
print(f\"  current_step:    {s['current_step']}\")
print(f\"  status:          {s['status']}\")
print(f\"  completed_steps: {', '.join(s.get('completed_steps', [])) or '(none)'}\")
print(f\"  updated_at:      {s['updated_at']}\")
if s.get('notes'):
  print(f\"  notes:           {s['notes']}\")
" "$STATE_FILE"
fi
