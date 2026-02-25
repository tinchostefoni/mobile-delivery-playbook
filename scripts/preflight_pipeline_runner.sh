#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/preflight_pipeline_runner.sh --repo <absolute-path> --base-branch <name> [options]

Options:
  --mode <setup|run>             Default: run
  --jira-project-key <KEY>       Optional expected Jira prefix (example: LSF)
  --jira-base-url <URL>          Jira base URL from setup config
  --figma-base-url <URL>         Figma base URL from setup config
  --jira-key <KEY-123>           Required only in run mode
  --figma-node-ids <csv>         Optional node ids for UI runs
  --run-mode <REAL_RUN|DRY_RUN|PLAN_ONLY>  Default: REAL_RUN
  --project-context-paths <csv>  Relative paths, comma-separated
  --write-artifacts <bool>       true|false (default: false)
  --artifacts-path <path>        Required only when --write-artifacts true
  --notify-google-chat <bool>    true|false (default: false)
  --verify-chat-webhook <bool>   true|false (default: false)
  --output-format <text|json>    Default: text
  --help                         Show this help
EOF
}

REPO_PATH=""
MODE="run"
JIRA_KEY=""
JIRA_PROJECT_KEY=""
JIRA_BASE_URL=""
FIGMA_BASE_URL=""
FIGMA_NODE_IDS=""
BASE_BRANCH=""
RUN_MODE="REAL_RUN"
PROJECT_CONTEXT_PATHS=""
WRITE_ARTIFACTS="false"
ARTIFACTS_PATH=""
NOTIFY_GOOGLE_CHAT="false"
VERIFY_CHAT_WEBHOOK="false"
OUTPUT_FORMAT="text"
WARNINGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_PATH="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --jira-key) JIRA_KEY="${2:-}"; shift 2 ;;
    --jira-project-key) JIRA_PROJECT_KEY="${2:-}"; shift 2 ;;
    --jira-base-url) JIRA_BASE_URL="${2:-}"; shift 2 ;;
    --figma-base-url) FIGMA_BASE_URL="${2:-}"; shift 2 ;;
    --figma-node-ids) FIGMA_NODE_IDS="${2:-}"; shift 2 ;;
    --base-branch) BASE_BRANCH="${2:-}"; shift 2 ;;
    --run-mode) RUN_MODE="${2:-}"; shift 2 ;;
    --project-context-paths) PROJECT_CONTEXT_PATHS="${2:-}"; shift 2 ;;
    --write-artifacts) WRITE_ARTIFACTS="${2:-}"; shift 2 ;;
    --artifacts-path) ARTIFACTS_PATH="${2:-}"; shift 2 ;;
    --notify-google-chat) NOTIFY_GOOGLE_CHAT="${2:-}"; shift 2 ;;
    --verify-chat-webhook) VERIFY_CHAT_WEBHOOK="${2:-}"; shift 2 ;;
    --output-format) OUTPUT_FORMAT="${2:-}"; shift 2 ;;
    -h|--help|--usage) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

emit_json() {
  local status="$1"
  local code="$2"
  local field="$3"
  local message="$4"
  local warnings_text="${5:-}"
  python3 - "$status" "$code" "$field" "$message" "$warnings_text" <<'PY'
import json, sys
status, code, field, message, warnings_text = sys.argv[1:]
warnings = [w for w in warnings_text.split("\n") if w]
out = {
  "status": status,
  "code": code,
  "field": field,
  "message": message,
  "warnings": warnings,
}
print(json.dumps(out, ensure_ascii=True))
PY
}

warnings_payload() {
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    printf "%s\n" "${WARNINGS[@]}"
  else
    printf ""
  fi
}

fail() {
  local code="$1"
  local field="$2"
  local message="$3"
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    emit_json "fail" "$code" "$field" "$message" "$(warnings_payload)"
  else
    echo "PRECHECK_FAIL [$code] ($field): $message" >&2
  fi
  exit 1
}

warn() {
  local message="$1"
  WARNINGS+=("$message")
  if [[ "$OUTPUT_FORMAT" == "text" ]]; then
    echo "PRECHECK_WARN: $message"
  fi
}

ok() {
  if [[ "$OUTPUT_FORMAT" == "text" ]]; then
    echo "PRECHECK_OK: $1"
  fi
}

bool_or_fail() {
  local v="$1"
  local field="$2"
  [[ "$v" == "true" || "$v" == "false" ]] || fail "INVALID_BOOLEAN" "$field" "Invalid boolean value: $v"
}

bool_or_fail "$WRITE_ARTIFACTS" "write_artifacts"
bool_or_fail "$NOTIFY_GOOGLE_CHAT" "notify_google_chat"
bool_or_fail "$VERIFY_CHAT_WEBHOOK" "verify_chat_webhook"

[[ "$OUTPUT_FORMAT" == "text" || "$OUTPUT_FORMAT" == "json" ]] || fail "INVALID_OUTPUT_FORMAT" "output_format" "Invalid output format: $OUTPUT_FORMAT"
[[ "$RUN_MODE" == "REAL_RUN" || "$RUN_MODE" == "DRY_RUN" || "$RUN_MODE" == "PLAN_ONLY" ]] || fail "INVALID_RUN_MODE" "run_mode" "Invalid run mode: $RUN_MODE"
[[ "$MODE" == "setup" || "$MODE" == "run" ]] || fail "INVALID_MODE" "mode" "Invalid mode: $MODE"
[[ -n "$REPO_PATH" ]] || fail "MISSING_REPO" "repo" "--repo is required"
[[ -n "$BASE_BRANCH" ]] || fail "MISSING_BASE_BRANCH" "base_branch" "--base-branch is required"
[[ -d "$REPO_PATH" ]] || fail "REPO_NOT_FOUND" "repo" "Repo path does not exist: $REPO_PATH"
[[ -d "$REPO_PATH/.git" ]] || fail "NOT_GIT_REPO" "repo" "Not a git repository: $REPO_PATH"

# 1) Jira key validation
if [[ "$MODE" == "run" ]]; then
  [[ -n "$JIRA_KEY" ]] || fail "MISSING_JIRA_KEY" "jira_key" "--jira-key is required in run mode"
  if [[ -n "$JIRA_PROJECT_KEY" ]]; then
    [[ "$JIRA_KEY" =~ ^${JIRA_PROJECT_KEY}-[0-9]+$ ]] || fail "INVALID_JIRA_PREFIX" "jira_key" "JIRA_KEY '$JIRA_KEY' does not match configured prefix '$JIRA_PROJECT_KEY'"
  else
    [[ "$JIRA_KEY" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]] || fail "INVALID_JIRA_FORMAT" "jira_key" "JIRA_KEY has invalid format: $JIRA_KEY"
  fi
  ok "Jira key format/prefix validated"
else
  ok "Setup mode: Jira key validation skipped"
fi

# 2) Base branch validation (special behavior)
if git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
  ok "Base branch exists locally: $BASE_BRANCH"
elif git -C "$REPO_PATH" show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
  warn "Base branch not local but exists on origin/$BASE_BRANCH; runner may fetch/track it automatically"
else
  # network check to avoid stale local refs false negatives
  if git -C "$REPO_PATH" ls-remote --exit-code --heads origin "$BASE_BRANCH" >/dev/null 2>&1; then
    warn "Base branch found on remote only: origin/$BASE_BRANCH; runner may fetch/track it automatically"
  else
    fail "BASE_BRANCH_NOT_FOUND" "base_branch" "Base branch '$BASE_BRANCH' does not exist locally or on origin"
  fi
fi

# 3) Dirty worktree (block for REAL_RUN)
if [[ "$MODE" == "run" && "$RUN_MODE" == "REAL_RUN" ]]; then
  if [[ -n "$(git -C "$REPO_PATH" status --porcelain)" ]]; then
    fail "DIRTY_WORKTREE" "repo" "Working tree is not clean for REAL_RUN"
  fi
fi
if [[ "$MODE" == "run" ]]; then
  ok "Worktree state validated for $RUN_MODE"
else
  ok "Setup mode: worktree cleanliness validation skipped"
fi

# 4) Context paths must exist (if provided)
if [[ -n "${PROJECT_CONTEXT_PATHS// }" ]]; then
  IFS=',' read -r -a paths <<< "$PROJECT_CONTEXT_PATHS"
  for rel in "${paths[@]}"; do
    rel="$(echo "$rel" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$rel" ]] && continue
    [[ -e "$REPO_PATH/$rel" ]] || fail "MISSING_CONTEXT_PATH" "project_context_paths" "PROJECT_CONTEXT_PATH does not exist: $rel"
  done
fi
ok "Project context paths validated"

# 5) Artifacts path policy
if [[ "$WRITE_ARTIFACTS" == "true" ]]; then
  [[ -n "$ARTIFACTS_PATH" ]] || fail "MISSING_ARTIFACTS_PATH" "artifacts_path" "ARTIFACTS_PATH is required when WRITE_ARTIFACTS=true"
  if [[ -e "$ARTIFACTS_PATH" ]]; then
    [[ -w "$ARTIFACTS_PATH" ]] || fail "ARTIFACTS_NOT_WRITABLE" "artifacts_path" "ARTIFACTS_PATH is not writable: $ARTIFACTS_PATH"
  else
    parent_dir="$(dirname "$ARTIFACTS_PATH")"
    [[ -d "$parent_dir" && -w "$parent_dir" ]] || fail "ARTIFACTS_PARENT_NOT_WRITABLE" "artifacts_path" "Cannot create ARTIFACTS_PATH at: $ARTIFACTS_PATH"
  fi
fi
ok "Artifact path policy validated"

# 6) Google Chat webhook validation (when notifications enabled)
if [[ "$NOTIFY_GOOGLE_CHAT" == "true" ]]; then
  [[ -n "${GOOGLE_CHAT_WEBHOOK_URL:-}" ]] || fail "MISSING_CHAT_WEBHOOK" "google_chat_webhook_url" "GOOGLE_CHAT_WEBHOOK_URL is required when NOTIFY_GOOGLE_CHAT=true"
  [[ "${GOOGLE_CHAT_WEBHOOK_URL}" =~ ^https://chat\.googleapis\.com/ ]] || fail "INVALID_CHAT_WEBHOOK" "google_chat_webhook_url" "GOOGLE_CHAT_WEBHOOK_URL is invalid format"

  if [[ "$VERIFY_CHAT_WEBHOOK" == "true" ]]; then
    http_code="$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$GOOGLE_CHAT_WEBHOOK_URL" \
      -H "Content-Type: application/json; charset=UTF-8" \
      -d '{"text":"Preflight webhook validation"}' || true)"
    [[ "$http_code" =~ ^2[0-9][0-9]$ ]] || fail "CHAT_WEBHOOK_UNREACHABLE" "google_chat_webhook_url" "GOOGLE_CHAT_WEBHOOK_URL reachable check failed (HTTP $http_code)"
  fi
fi
ok "Google Chat configuration validated"

# 7) Base URL validations
[[ -n "$JIRA_BASE_URL" ]] || fail "MISSING_JIRA_BASE_URL" "jira_base_url" "JIRA_BASE_URL is required from setup config"
[[ "$JIRA_BASE_URL" =~ ^https?:// ]] || fail "INVALID_JIRA_BASE_URL" "jira_base_url" "JIRA_BASE_URL is invalid format: $JIRA_BASE_URL"

if [[ -n "${FIGMA_NODE_IDS// }" ]]; then
  [[ -n "$FIGMA_BASE_URL" ]] || fail "MISSING_FIGMA_BASE_URL" "figma_base_url" "FIGMA_BASE_URL is required when FIGMA_NODE_IDS is provided"
  [[ "$FIGMA_BASE_URL" =~ ^https?:// ]] || fail "INVALID_FIGMA_BASE_URL" "figma_base_url" "FIGMA_BASE_URL is invalid format: $FIGMA_BASE_URL"
fi
ok "Base URL configuration validated"

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  emit_json "ok" "OK" "preflight" "All validations passed" "$(warnings_payload)"
else
  echo "PRECHECK_OK: all validations passed"
fi
