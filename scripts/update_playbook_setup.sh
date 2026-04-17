#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/update_playbook_setup.sh [--repo <absolute-path>] [options]

Updates existing .playbook/playbook.config.yml without re-running full bootstrap detection.

Options:
  --project-name <NAME>
  --jira-project-key <KEY>
  --jira-base-url <URL>
  --figma-base-url <URL>
  --base-branch <NAME>
  --notify-google-chat <true|false>
  --auto-detect-context <true|false>
  --write-artifacts <true|false>
  --artifacts-path <PATH>     Optional. Used only when write-artifacts=true.
  -h, --help                  Show this help
EOF
}

REPO_PATH=""
PROJECT_NAME=""
JIRA_PROJECT_KEY=""
JIRA_BASE_URL=""
FIGMA_BASE_URL=""
BASE_BRANCH=""
NOTIFY_GOOGLE_CHAT=""
AUTO_DETECT_CONTEXT=""
WRITE_ARTIFACTS=""
ARTIFACTS_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_PATH="${2:-}"; shift 2 ;;
    --project-name) PROJECT_NAME="${2:-}"; shift 2 ;;
    --jira-project-key) JIRA_PROJECT_KEY="${2:-}"; shift 2 ;;
    --jira-base-url) JIRA_BASE_URL="${2:-}"; shift 2 ;;
    --figma-base-url) FIGMA_BASE_URL="${2:-}"; shift 2 ;;
    --base-branch) BASE_BRANCH="${2:-}"; shift 2 ;;
    --notify-google-chat) NOTIFY_GOOGLE_CHAT="${2:-}"; shift 2 ;;
    --auto-detect-context) AUTO_DETECT_CONTEXT="${2:-}"; shift 2 ;;
    --write-artifacts) WRITE_ARTIFACTS="${2:-}"; shift 2 ;;
    --artifacts-path) ARTIFACTS_PATH="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

fail() {
  echo "$1" >&2
  exit 1
}

bool_or_fail() {
  local value="$1"
  [[ "$value" == "true" || "$value" == "false" ]] || fail "Invalid boolean: $value"
}

scalar_from_yaml() {
  local file="$1"
  local key="$2"
  local raw
  raw="$(sed -n "s/^  ${key}: //p" "$file" | head -n 1)"
  raw="${raw%\"}"
  raw="${raw#\"}"
  printf '%s' "$raw"
}

if [[ -z "$REPO_PATH" ]]; then
  current_repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$current_repo_root" && -f "$current_repo_root/.playbook/playbook.config.yml" ]]; then
    current_config="$current_repo_root/.playbook/playbook.config.yml"
    configured_repo_from_init="$(sed -n 's/^  repo_path: //p' "$current_config" | head -n 1)"
    configured_repo_from_init="${configured_repo_from_init%\"}"
    configured_repo_from_init="${configured_repo_from_init#\"}"
    REPO_PATH="${configured_repo_from_init:-$current_repo_root}"
  fi
fi

if [[ -z "$REPO_PATH" ]]; then
  fail "Cannot resolve REPO_PATH from existing playbook config. Pass --repo or run from a repository that already has .playbook/playbook.config.yml."
fi

[[ -d "$REPO_PATH" ]] || fail "Repo path does not exist: $REPO_PATH"
[[ -d "$REPO_PATH/.git" ]] || fail "Not a git repository: $REPO_PATH"

CONFIG_FILE="$REPO_PATH/.playbook/playbook.config.yml"
[[ -f "$CONFIG_FILE" ]] || fail "Missing $CONFIG_FILE. Run playbook-setup init first."

existing_project_name="$(scalar_from_yaml "$CONFIG_FILE" "name")"
existing_repo_path="$(scalar_from_yaml "$CONFIG_FILE" "repo_path")"
existing_jira_project_key="$(scalar_from_yaml "$CONFIG_FILE" "jira_project_key")"
existing_jira_base_url="$(scalar_from_yaml "$CONFIG_FILE" "jira_base_url")"
existing_figma_base_url="$(scalar_from_yaml "$CONFIG_FILE" "figma_base_url")"
existing_base_branch="$(scalar_from_yaml "$CONFIG_FILE" "target_base_branch")"
existing_notify_google_chat="$(scalar_from_yaml "$CONFIG_FILE" "notify_google_chat")"
existing_auto_detect_context="$(scalar_from_yaml "$CONFIG_FILE" "auto_detect_context")"
existing_write_artifacts="$(scalar_from_yaml "$CONFIG_FILE" "write_artifacts")"
existing_artifacts_path="$(scalar_from_yaml "$CONFIG_FILE" "artifacts_path")"

PROJECT_NAME="${PROJECT_NAME:-$existing_project_name}"
JIRA_PROJECT_KEY="${JIRA_PROJECT_KEY:-$existing_jira_project_key}"
JIRA_BASE_URL="${JIRA_BASE_URL:-$existing_jira_base_url}"
FIGMA_BASE_URL="${FIGMA_BASE_URL:-$existing_figma_base_url}"
BASE_BRANCH="${BASE_BRANCH:-$existing_base_branch}"
NOTIFY_GOOGLE_CHAT="${NOTIFY_GOOGLE_CHAT:-$existing_notify_google_chat}"
AUTO_DETECT_CONTEXT="${AUTO_DETECT_CONTEXT:-$existing_auto_detect_context}"
WRITE_ARTIFACTS="${WRITE_ARTIFACTS:-$existing_write_artifacts}"
ARTIFACTS_PATH="${ARTIFACTS_PATH:-$existing_artifacts_path}"

bool_or_fail "$NOTIFY_GOOGLE_CHAT"
bool_or_fail "$AUTO_DETECT_CONTEXT"
bool_or_fail "$WRITE_ARTIFACTS"

[[ -n "$JIRA_BASE_URL" ]] || fail "JIRA_BASE_URL is required"
[[ "$JIRA_BASE_URL" =~ ^https?:// ]] || fail "Invalid JIRA_BASE_URL: $JIRA_BASE_URL"
if [[ -n "$FIGMA_BASE_URL" ]]; then
  [[ "$FIGMA_BASE_URL" =~ ^https?:// ]] || fail "Invalid FIGMA_BASE_URL: $FIGMA_BASE_URL"
fi

if git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
  :
elif git -C "$REPO_PATH" show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
  :
elif git -C "$REPO_PATH" ls-remote --exit-code --heads origin "$BASE_BRANCH" >/dev/null 2>&1; then
  :
else
  fail "Base branch '$BASE_BRANCH' does not exist locally or on origin"
fi

if [[ "$WRITE_ARTIFACTS" == "true" && -z "$ARTIFACTS_PATH" ]]; then
  ARTIFACTS_PATH="$REPO_PATH/.playbook/pipeline-runner"
fi

context_block="$(awk '/^context:/{flag=1} flag{print}' "$CONFIG_FILE")"
[[ -n "$context_block" ]] || fail "Invalid config: missing context block"

cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"

{
  echo "version: 1"
  echo "project:"
  echo "  name: \"$PROJECT_NAME\""
  echo "  repo_path: \"$existing_repo_path\""
  echo "  jira_project_key: \"$JIRA_PROJECT_KEY\""
  echo "integrations:"
  echo "  jira_base_url: \"$JIRA_BASE_URL\""
  echo "  figma_base_url: \"$FIGMA_BASE_URL\""
  echo "pipeline:"
  echo "  target_base_branch: \"$BASE_BRANCH\""
  echo "  notify_google_chat: $NOTIFY_GOOGLE_CHAT"
  echo "  auto_detect_context: $AUTO_DETECT_CONTEXT"
  echo "  write_artifacts: $WRITE_ARTIFACTS"
  if [[ "$WRITE_ARTIFACTS" == "true" ]]; then
    echo "  artifacts_path: \"$ARTIFACTS_PATH\""
  fi
  echo "$context_block"
} > "$CONFIG_FILE"

context_csv="$(
  awk '
    /^  project_context_paths:/ {in_paths=1; next}
    in_paths && /^    - / {
      gsub(/^    - "/, "", $0); gsub(/"$/, "", $0);
      print $0
      next
    }
    in_paths && !/^    - / {in_paths=0}
  ' "$CONFIG_FILE" | paste -sd, - || true
)"

preflight_cmd=(
  "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/preflight_pipeline_runner.sh"
  --mode setup
  --repo "$REPO_PATH"
  --base-branch "$BASE_BRANCH"
  --jira-project-key "$JIRA_PROJECT_KEY"
  --jira-base-url "$JIRA_BASE_URL"
  --figma-base-url "$FIGMA_BASE_URL"
  --project-context-paths "$context_csv"
  --write-artifacts "$WRITE_ARTIFACTS"
  --notify-google-chat "$NOTIFY_GOOGLE_CHAT"
)
if [[ "$WRITE_ARTIFACTS" == "true" ]]; then
  preflight_cmd+=(--artifacts-path "$ARTIFACTS_PATH")
fi

"${preflight_cmd[@]}"

echo "Updated: $CONFIG_FILE"
