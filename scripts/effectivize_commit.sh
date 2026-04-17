#!/usr/bin/env bash
set -euo pipefail

# effectivize_commit.sh — Stage and commit code changes following playbook conventions.
#
# Applies the commit-message template, stages appropriate files (excludes pipeline
# artifacts and secrets), creates the commit, and optionally pushes to origin.
#
# Usage:
#   bash scripts/effectivize_commit.sh \
#     --repo        <absolute-path>     \
#     --jira-key    <KEY-123>           \
#     --type        <feat|fix|chore|…>  \
#     --scope       <module-or-area>    \
#     --message     "<short description>" \
#     [--body       "<multi-line body>"] \
#     [--push]                          \
#     [--output-format text|json]
#
# Commit message format (from template):
#   <type>(<scope>): <short description>
#
# Excluded from staging (never committed by this script):
#   .env.playbook
#   .playbook/pipeline-runner/**   (runtime artifacts)
#
# Exit codes: 0=success, 1=nothing to commit, 2=usage error

usage() {
  cat <<'EOF'
Usage: bash scripts/effectivize_commit.sh --repo <path> --jira-key <KEY> --type <type> --scope <scope> --message <msg> [options]
Options:
  --repo <path>          Absolute path to git repository
  --jira-key <KEY-123>   Jira issue key (optional, not included in commit subject)
  --type <type>          Conventional commit type (feat, fix, chore, refactor, test, docs...)
  --scope <scope>        Conventional commit scope (module, area, layer)
  --message <text>       Short commit description (imperative mood)
  --body <text>          Optional extended commit body
  --push                 Push branch to origin after committing
  --output-format        text|json (default: text)
  --help                 Show this help
EOF
}

REPO_PATH=""
JIRA_KEY=""
COMMIT_TYPE=""
COMMIT_SCOPE=""
COMMIT_MSG=""
COMMIT_BODY=""
DO_PUSH="false"
OUTPUT_FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)           REPO_PATH="${2:-}"; shift 2 ;;
    --jira-key)       JIRA_KEY="${2:-}"; shift 2 ;;
    --type)           COMMIT_TYPE="${2:-}"; shift 2 ;;
    --scope)          COMMIT_SCOPE="${2:-}"; shift 2 ;;
    --message)        COMMIT_MSG="${2:-}"; shift 2 ;;
    --body)           COMMIT_BODY="${2:-}"; shift 2 ;;
    --push)           DO_PUSH="true"; shift ;;
    --output-format)  OUTPUT_FORMAT="${2:-}"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$REPO_PATH" ]]    || { echo "ERROR: --repo is required" >&2; exit 2; }
[[ -n "$COMMIT_TYPE" ]]  || { echo "ERROR: --type is required" >&2; exit 2; }
[[ -n "$COMMIT_SCOPE" ]] || { echo "ERROR: --scope is required" >&2; exit 2; }
[[ -n "$COMMIT_MSG" ]]   || { echo "ERROR: --message is required" >&2; exit 2; }

# Build conventional commit subject line
COMMIT_SUBJECT="${COMMIT_TYPE}(${COMMIT_SCOPE}): ${COMMIT_MSG}"

# Assemble full commit message
if [[ -n "$COMMIT_BODY" ]]; then
  FULL_MESSAGE="${COMMIT_SUBJECT}

${COMMIT_BODY}"
else
  FULL_MESSAGE="$COMMIT_SUBJECT"
fi

# ─────────────────────────────────────────────────────────
# Stage files (exclude secrets and pipeline artifacts)
# ─────────────────────────────────────────────────────────
cd "$REPO_PATH"

# Add all tracked + untracked except excluded paths
git add --all -- \
  ':!.env.playbook' \
  ':!.playbook/pipeline-runner/'

# Check if there's anything to commit
if git diff --cached --quiet; then
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo '{"status":"nothing_to_commit","message":"No staged changes to commit"}'
  else
    echo "COMMIT_SKIP: Nothing to commit after staging."
  fi
  exit 1
fi

# ─────────────────────────────────────────────────────────
# Create commit
# ─────────────────────────────────────────────────────────
COMMIT_HASH="$(git commit -m "$FULL_MESSAGE" --quiet && git rev-parse --short HEAD)"

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  BRANCH="$(git branch --show-current)"
  python3 -c "
import json
print(json.dumps({
  'status': 'committed',
  'hash': '$COMMIT_HASH',
  'branch': '$BRANCH',
  'subject': '$COMMIT_SUBJECT',
  'pushed': False,
}))
"
else
  echo "COMMITTED [$COMMIT_HASH]: $COMMIT_SUBJECT"
fi

# ─────────────────────────────────────────────────────────
# Optional push
# ─────────────────────────────────────────────────────────
if [[ "$DO_PUSH" == "true" ]]; then
  BRANCH="$(git branch --show-current)"
  git push origin "$BRANCH"
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    python3 -c "
import json
print(json.dumps({
  'status': 'committed_and_pushed',
  'hash': '$COMMIT_HASH',
  'branch': '$BRANCH',
  'subject': '$COMMIT_SUBJECT',
  'pushed': True,
}))
"
  else
    echo "PUSHED: origin/$BRANCH"
  fi
fi
