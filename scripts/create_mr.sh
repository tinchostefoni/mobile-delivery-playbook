#!/usr/bin/env bash
set -euo pipefail

# create_mr.sh — Create a GitLab Merge Request without requiring a GitLab MCP.
#
# Strategy (tried in order):
#   1. glab CLI (if installed and authenticated)
#   2. curl + GitLab API with GITLAB_TOKEN
#   3. Manual fallback: prints pre-filled URL and MR package for browser submission
#
# Usage:
#   bash scripts/create_mr.sh \
#     --repo       <absolute-path>        \
#     --source     <source-branch>        \
#     --target     <target-branch>        \
#     --title      "<MR title>"           \
#     --desc       "<MR description>"     \
#     [--jira-key  <JIRA-123>]            \
#     [--remove-source-branch]            \
#     [--squash]                          \
#     [--output-format text|json]
#
# Exit codes: 0=created, 1=fallback (manual), 2=usage error

usage() {
  cat <<'EOF'
Usage: bash scripts/create_mr.sh --repo <path> --source <branch> --target <branch> --title <title> --desc <desc> [options]
Options:
  --repo <path>              Absolute path to the target git repository
  --source <branch>          Source branch for the MR
  --target <branch>          Target branch for the MR
  --title <text>             MR title
  --desc <text>              MR description body
  --jira-key <KEY-123>       Optional Jira issue key (for context only)
  --remove-source-branch     Set remove_source_branch=true in GitLab API (default: false)
  --squash                   Set squash=true in GitLab API (default: false)
  --output-format text|json  Default: text
  --help                     Show this help
EOF
}

REPO_PATH=""
SOURCE_BRANCH=""
TARGET_BRANCH=""
MR_TITLE=""
MR_DESC=""
JIRA_KEY=""
REMOVE_SOURCE_BRANCH="false"
SQUASH="false"
OUTPUT_FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)                   REPO_PATH="${2:-}"; shift 2 ;;
    --source)                 SOURCE_BRANCH="${2:-}"; shift 2 ;;
    --target)                 TARGET_BRANCH="${2:-}"; shift 2 ;;
    --title)                  MR_TITLE="${2:-}"; shift 2 ;;
    --desc)                   MR_DESC="${2:-}"; shift 2 ;;
    --jira-key)               JIRA_KEY="${2:-}"; shift 2 ;;
    --remove-source-branch)   REMOVE_SOURCE_BRANCH="true"; shift ;;
    --squash)                 SQUASH="true"; shift ;;
    --output-format)          OUTPUT_FORMAT="${2:-}"; shift 2 ;;
    -h|--help|--usage)        usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$REPO_PATH" ]]      || { echo "ERROR: --repo is required" >&2; exit 2; }
[[ -n "$SOURCE_BRANCH" ]]  || { echo "ERROR: --source is required" >&2; exit 2; }
[[ -n "$TARGET_BRANCH" ]]  || { echo "ERROR: --target is required" >&2; exit 2; }
[[ -n "$MR_TITLE" ]]       || { echo "ERROR: --title is required" >&2; exit 2; }

# Auto-load .env.playbook if present
_env_file=""
for _candidate in "$REPO_PATH/.env.playbook" "$(git -C "$REPO_PATH" rev-parse --show-toplevel 2>/dev/null)/.env.playbook"; do
  if [[ -f "$_candidate" ]]; then _env_file="$_candidate"; break; fi
done
if [[ -n "$_env_file" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$_env_file"; set +a
fi

GITLAB_TOKEN="${GITLAB_TOKEN:-}"
GITLAB_API_URL="${GITLAB_API_URL:-https://gitlab.com/api/v4}"

# Helper: emit structured output
emit_result() {
  local status="$1" strategy="$2" mr_url="${3:-}" message="${4:-}"
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    python3 -c "
import json, sys
print(json.dumps({
  'status': '$status',
  'strategy': '$strategy',
  'mr_url': '$mr_url',
  'message': '$message',
}))
"
  else
    if [[ "$status" == "created" ]]; then
      echo "MR_CREATED [via $strategy]: $mr_url"
    else
      echo "MR_FALLBACK [via $strategy]: $mr_url"
      echo "$message"
    fi
  fi
}

# Helper: extract GitLab namespace/project from remote URL
extract_gl_project() {
  local remote_url
  remote_url="$(git -C "$REPO_PATH" remote get-url origin 2>/dev/null || true)"
  # Handles: git@gitlab.com:ns/repo.git and https://gitlab.com/ns/repo.git
  echo "$remote_url" \
    | sed -E 's|.*[:/]([^/]+/[^/]+)\.git$|\1|' \
    | sed -E 's|.*[:/]([^/]+/[^/]+)$|\1|'
}

# URL-encode a string
urlencode() {
  python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# ─────────────────────────────────────────────────────────
# Strategy 1: glab CLI
# ─────────────────────────────────────────────────────────
if command -v glab >/dev/null 2>&1; then
  echo "Attempting MR creation via glab CLI..." >&2
  remove_flag=""
  [[ "$REMOVE_SOURCE_BRANCH" == "true" ]] && remove_flag="--remove-source-branch"
  squash_flag=""
  [[ "$SQUASH" == "true" ]] && squash_flag="--squash"

  # shellcheck disable=SC2086
  mr_url="$(
    glab mr create \
      --repo "$(extract_gl_project)" \
      --source-branch "$SOURCE_BRANCH" \
      --target-branch "$TARGET_BRANCH" \
      --title "$MR_TITLE" \
      --description "$MR_DESC" \
      --yes \
      $remove_flag $squash_flag \
      --output json 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('web_url',''))"
  )" || true

  if [[ -n "$mr_url" && "$mr_url" =~ ^https?:// ]]; then
    emit_result "created" "glab" "$mr_url" "MR created successfully"
    exit 0
  fi
  echo "glab did not return a valid MR URL, trying next strategy..." >&2
fi

# ─────────────────────────────────────────────────────────
# Strategy 2: curl + GitLab REST API
# ─────────────────────────────────────────────────────────
if [[ -n "$GITLAB_TOKEN" ]]; then
  echo "Attempting MR creation via GitLab API..." >&2

  GL_PROJECT="$(extract_gl_project)"
  GL_PROJECT_ENCODED="$(urlencode "$GL_PROJECT")"

  payload="$(python3 -c "
import json, sys
print(json.dumps({
  'source_branch': '$SOURCE_BRANCH',
  'target_branch': '$TARGET_BRANCH',
  'title': sys.argv[1],
  'description': sys.argv[2],
  'remove_source_branch': $REMOVE_SOURCE_BRANCH,
  'squash': $SQUASH,
}))
" "$MR_TITLE" "$MR_DESC")"

  response="$(
    curl -sS -w "\n__HTTP_STATUS__%{http_code}" \
      -X POST "${GITLAB_API_URL}/projects/${GL_PROJECT_ENCODED}/merge_requests" \
      -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$payload" 2>/dev/null || true
  )"

  http_status="$(echo "$response" | tail -1 | sed 's/__HTTP_STATUS__//')"
  response_body="$(echo "$response" | head -n -1)"

  if [[ "$http_status" =~ ^2[0-9][0-9]$ ]]; then
    mr_url="$(echo "$response_body" | python3 -c "import json,sys; print(json.load(sys.stdin).get('web_url',''))" 2>/dev/null || true)"
    if [[ -n "$mr_url" ]]; then
      emit_result "created" "gitlab-api" "$mr_url" "MR created via API (HTTP $http_status)"
      exit 0
    fi
  fi
  echo "GitLab API returned HTTP $http_status, falling through to manual fallback..." >&2
fi

# ─────────────────────────────────────────────────────────
# Strategy 3: Manual fallback — generate pre-filled URL + package
# ─────────────────────────────────────────────────────────
echo "Generating manual MR fallback package..." >&2

REMOTE_URL="$(git -C "$REPO_PATH" remote get-url origin 2>/dev/null || echo '')"
GL_WEB_BASE="$(echo "$REMOTE_URL" | sed -E 's|\.git$||; s|git@([^:]+):(.+)|https://\1/\2|')"
GL_PROJECT_PATH="$(extract_gl_project)"

SOURCE_ENC="$(urlencode "$SOURCE_BRANCH")"
TARGET_ENC="$(urlencode "$TARGET_BRANCH")"
TITLE_ENC="$(urlencode "$MR_TITLE")"

NEW_MR_URL="${GL_WEB_BASE}/-/merge_requests/new?merge_request[source_branch]=${SOURCE_ENC}&merge_request[target_branch]=${TARGET_ENC}&merge_request[title]=${TITLE_ENC}"

PACKAGE="
════════════════════════════════════════
 CREATE MR MANUALLY — Pre-filled package
════════════════════════════════════════
Reason: No glab CLI detected and GITLAB_TOKEN not set.
Set GITLAB_TOKEN in .env.playbook to enable automatic MR creation.

Project:       $GL_PROJECT_PATH
Source branch: $SOURCE_BRANCH
Target branch: $TARGET_BRANCH
Title:         $MR_TITLE

Direct URL (click to open pre-filled MR form):
$NEW_MR_URL

Description to paste:
────────────────────
$MR_DESC
────────────────────
════════════════════════════════════════"

emit_result "fallback" "manual-url" "$NEW_MR_URL" "$PACKAGE"
exit 1
