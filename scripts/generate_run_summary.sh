#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/generate_run_summary.sh \
    --jira-key <KEY-123> \
    --run-mode <REAL_RUN|DRY_RUN|PLAN_ONLY> \
    --status <success|warning|blocked|error> \
    --repo-root <absolute-path> \
    [--summary <text>] \
    [--next-action <text>] \
    [--output <path>]

Notes:
  - By default writes to <repo-root>/.codex/pipeline-runner/<JIRA_KEY>/run_summary.md
  - Content is mode-aware (PLAN_ONLY vs REAL_RUN/DRY_RUN).
EOF
}

JIRA_KEY=""
RUN_MODE=""
STATUS=""
REPO_ROOT=""
SUMMARY=""
NEXT_ACTION=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jira-key) JIRA_KEY="${2:-}"; shift 2 ;;
    --run-mode) RUN_MODE="${2:-}"; shift 2 ;;
    --status) STATUS="${2:-}"; shift 2 ;;
    --repo-root) REPO_ROOT="${2:-}"; shift 2 ;;
    --summary) SUMMARY="${2:-}"; shift 2 ;;
    --next-action) NEXT_ACTION="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$JIRA_KEY" ]] || { echo "--jira-key is required" >&2; exit 1; }
[[ -n "$RUN_MODE" ]] || { echo "--run-mode is required" >&2; exit 1; }
[[ -n "$STATUS" ]] || { echo "--status is required" >&2; exit 1; }
[[ -n "$REPO_ROOT" ]] || { echo "--repo-root is required" >&2; exit 1; }

case "$RUN_MODE" in
  REAL_RUN|DRY_RUN|PLAN_ONLY) ;;
  *) echo "Invalid --run-mode: $RUN_MODE" >&2; exit 1 ;;
esac

case "$STATUS" in
  success|warning|blocked|error) ;;
  *) echo "Invalid --status: $STATUS" >&2; exit 1 ;;
esac

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="${REPO_ROOT}/.codex/pipeline-runner/${JIRA_KEY}/run_summary.md"
fi

mkdir -p "$(dirname "$OUTPUT")"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "# Run Summary"
  echo
  echo "- Jira: \`$JIRA_KEY\`"
  echo "- Run mode: \`$RUN_MODE\`"
  echo "- Status: \`$STATUS\`"
  echo "- Generated at (UTC): \`$ts\`"
  echo "- Repo: \`$REPO_ROOT\`"
  echo
  echo "## Summary"
  echo "${SUMMARY:-No summary provided.}"
  echo
  if [[ "$RUN_MODE" == "PLAN_ONLY" ]]; then
    echo "## Plan"
    echo "- Objective:"
    echo "- Proposed approach:"
    echo "- Impacted modules:"
    echo
    echo "## Forecast Files"
    echo "- (list expected paths)"
    echo
    echo "## Risks and Unknowns"
    echo "- Risks:"
    echo "- Unknowns:"
    echo
    echo "## Next Action"
    echo "${NEXT_ACTION:-Review plan and choose REAL_RUN or DRY_RUN.}"
  else
    echo "## Scope"
    echo "- Planned:"
    echo "- Executed:"
    echo "- Out of scope:"
    echo
    echo "## Changed Files"
    echo "- (list paths)"
    echo
    echo "## Validation"
    echo "- Preflight:"
    echo "- Local checks:"
    echo "- QA gate:"
    echo
    echo "## Risks and Blockers"
    echo "- Risks:"
    echo "- Blockers:"
    echo
    echo "## Next Action"
    echo "${NEXT_ACTION:-Awaiting user command.}"
  fi
} > "$OUTPUT"

echo "$OUTPUT"
