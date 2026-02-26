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

if [[ -z "$NEXT_ACTION" ]]; then
  if [[ "$RUN_MODE" == "PLAN_ONLY" ]]; then
    NEXT_ACTION="Refine summary/context and run DRY_RUN."
  elif [[ "$RUN_MODE" == "DRY_RUN" ]]; then
    NEXT_ACTION="If output looks correct, run REAL_RUN."
  else
    case "$STATUS" in
      success) NEXT_ACTION="If ready, send EFFECTIVIZE_COMMIT, CREATE_MR, or EFFECTIVIZE_COMMIT_AND_CREATE_MR." ;;
      warning) NEXT_ACTION="Address warnings, then rerun REAL_RUN or proceed with explicit user approval." ;;
      blocked|error) NEXT_ACTION="Resolve blockers and rerun from PLAN_ONLY or DRY_RUN before REAL_RUN." ;;
      *) NEXT_ACTION="Review output and decide next command." ;;
    esac
  fi
fi

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
    echo "## Recommended Next Step"
    echo "$NEXT_ACTION"
  else
    echo "## Planned Changes (Technical)"
    echo "- Files/modules to change:"
    echo "- Behavior changes expected:"
    echo
    echo "## Non-Changes (Guardrails)"
    echo "- Files/modules explicitly out of scope:"
    echo "- Behaviors that must remain unchanged:"
    echo
    echo "## Plan Diff"
    echo "- Delta vs previous PLAN_ONLY/DRY_RUN:"
    echo "- Reason for delta:"
    echo
    echo "## Architecture Impact"
    echo "- Intended architecture:"
    echo "- Alignment/deviation:"
    echo
    echo "## Unplanned Changes Rationale"
    echo "- List every unplanned change and technical reason:"
    echo
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
    echo "## Recommended Next Step"
    echo "$NEXT_ACTION"
  fi
} > "$OUTPUT"

echo "$OUTPUT"
