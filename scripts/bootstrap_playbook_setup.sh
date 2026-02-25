#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/bootstrap_playbook_setup.sh --repo <absolute-path> [options]

Options:
  --jira-project-key <KEY>     Jira project key prefix (example: LSF)
  --jira-base-url <URL>        Jira base URL (required, example: https://your-domain.atlassian.net)
  --figma-base-url <URL>       Figma design base URL (optional, example: https://www.figma.com/design/<fileKey>/<name>)
  --project-name <NAME>        Friendly project name
  --base-branch <NAME>         Base branch (dev|develop|development)
  --auto-detect-context <bool> true|false (default: true)
  --notify-google-chat <bool>  true|false (default: true)
  --write-artifacts <bool>     true|false (default: false)
  --artifacts-path <PATH>      Optional; default <repo>/.codex/pipeline-runner

Output files (inside target repo):
  .codex/playbook.config.yml
  .codex/project_context.auto.md (only when auto-detect true)
  .codex/project_context_paths.auto.txt (only when auto-detect true)
EOF
}

REPO_PATH=""
JIRA_PROJECT_KEY=""
JIRA_BASE_URL=""
FIGMA_BASE_URL=""
PROJECT_NAME=""
BASE_BRANCH=""
AUTO_DETECT_CONTEXT="true"
NOTIFY_GOOGLE_CHAT="true"
WRITE_ARTIFACTS="false"
ARTIFACTS_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_PATH="${2:-}"; shift 2 ;;
    --jira-project-key) JIRA_PROJECT_KEY="${2:-}"; shift 2 ;;
    --jira-base-url) JIRA_BASE_URL="${2:-}"; shift 2 ;;
    --figma-base-url) FIGMA_BASE_URL="${2:-}"; shift 2 ;;
    --project-name) PROJECT_NAME="${2:-}"; shift 2 ;;
    --base-branch) BASE_BRANCH="${2:-}"; shift 2 ;;
    --auto-detect-context) AUTO_DETECT_CONTEXT="${2:-}"; shift 2 ;;
    --notify-google-chat) NOTIFY_GOOGLE_CHAT="${2:-}"; shift 2 ;;
    --write-artifacts) WRITE_ARTIFACTS="${2:-}"; shift 2 ;;
    --artifacts-path) ARTIFACTS_PATH="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$REPO_PATH" ]]; then
  echo "--repo is required" >&2
  usage
  exit 1
fi

if [[ ! -d "$REPO_PATH" ]]; then
  echo "Repo path does not exist: $REPO_PATH" >&2
  exit 1
fi

if [[ ! -d "$REPO_PATH/.git" ]]; then
  echo "Not a git repository: $REPO_PATH" >&2
  exit 1
fi

detect_base_branch() {
  local repo="$1"
  local candidate
  for candidate in development develop dev; do
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$candidate"; then
      echo "$candidate"
      return 0
    fi
    if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  git -C "$repo" branch --show-current
}

detect_project_name() {
  local repo="$1"
  local xcodeproj
  xcodeproj="$(find "$repo" -maxdepth 3 -name '*.xcodeproj' -type d | head -n 1 || true)"
  if [[ -n "$xcodeproj" ]]; then
    basename "$xcodeproj" .xcodeproj
    return 0
  fi
  basename "$repo"
}

bool_or_fail() {
  local value="$1"
  if [[ "$value" != "true" && "$value" != "false" ]]; then
    echo "Invalid boolean value: $value (expected true|false)" >&2
    exit 1
  fi
}

bool_or_fail "$NOTIFY_GOOGLE_CHAT"
bool_or_fail "$WRITE_ARTIFACTS"
bool_or_fail "$AUTO_DETECT_CONTEXT"

if [[ "$WRITE_ARTIFACTS" == "true" && -z "$ARTIFACTS_PATH" ]]; then
  echo "--artifacts-path is required when --write-artifacts true" >&2
  exit 1
fi

if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH="$(detect_base_branch "$REPO_PATH")"
fi

if [[ -z "$PROJECT_NAME" ]]; then
  PROJECT_NAME="$(detect_project_name "$REPO_PATH")"
fi

if [[ -z "$ARTIFACTS_PATH" ]]; then
  ARTIFACTS_PATH="$REPO_PATH/.codex/pipeline-runner"
fi

if [[ -n "$JIRA_BASE_URL" ]]; then
  [[ "$JIRA_BASE_URL" =~ ^https?:// ]] || { echo "Invalid --jira-base-url: $JIRA_BASE_URL" >&2; exit 1; }
fi
if [[ -n "$FIGMA_BASE_URL" ]]; then
  [[ "$FIGMA_BASE_URL" =~ ^https?:// ]] || { echo "Invalid --figma-base-url: $FIGMA_BASE_URL" >&2; exit 1; }
fi

if [[ -z "$JIRA_BASE_URL" ]]; then
  echo "--jira-base-url is required" >&2
  exit 1
fi

find_first_file_by_pattern() {
  local repo="$1"
  local pattern="$2"
  rg --files "$repo" 2>/dev/null | rg -n "$pattern" --no-line-number | head -n 1 || true
}

TECH_CONTEXT_LINES=()
declare -a CONTEXT_PATHS=()

if [[ "$AUTO_DETECT_CONTEXT" == "true" ]]; then
  HAS_COORDINATOR="false"
  HAS_MVVM="false"
  HAS_NETWORKING="false"
  HAS_PUSH_NOTIF="false"
  HAS_STORAGE="false"
  HAS_UNIT_TESTS="false"
  HAS_UI_TESTS="false"

  if rg -n "Coordinator" "$REPO_PATH" --glob '!**/.git/**' --glob '*.swift' >/dev/null 2>&1; then HAS_COORDINATOR="true"; fi
  if rg -n "ViewModel" "$REPO_PATH" --glob '!**/.git/**' --glob '*.swift' >/dev/null 2>&1; then HAS_MVVM="true"; fi
  if rg -n "URLSession|Alamofire|Moya" "$REPO_PATH" --glob '!**/.git/**' --glob '*.swift' >/dev/null 2>&1; then HAS_NETWORKING="true"; fi
  if rg -n "FirebaseMessaging|UNUserNotificationCenter|NotificationCenter" "$REPO_PATH" --glob '!**/.git/**' --glob '*.swift' >/dev/null 2>&1; then HAS_PUSH_NOTIF="true"; fi
  if rg -n "CoreData|Realm|UserDefaults|Keychain" "$REPO_PATH" --glob '!**/.git/**' --glob '*.swift' >/dev/null 2>&1; then HAS_STORAGE="true"; fi
  if find "$REPO_PATH" -maxdepth 3 -type d -name '*Tests*' | rg -n '.' >/dev/null 2>&1; then HAS_UNIT_TESTS="true"; fi
  if find "$REPO_PATH" -maxdepth 4 -type d \( -name '*UITests*' -o -name '*UI Tests*' \) | rg -n '.' >/dev/null 2>&1; then HAS_UI_TESTS="true"; fi

  TECH_CONTEXT_LINES+=("Project bootstrap autodetected from repository structure.")
  if [[ "$HAS_COORDINATOR" == "true" && "$HAS_MVVM" == "true" ]]; then
    TECH_CONTEXT_LINES+=("Architecture appears to use Coordinator + MVVM.")
  elif [[ "$HAS_COORDINATOR" == "true" ]]; then
    TECH_CONTEXT_LINES+=("Architecture appears to use Coordinator-style flow composition.")
  elif [[ "$HAS_MVVM" == "true" ]]; then
    TECH_CONTEXT_LINES+=("Presentation layer appears to use ViewModel patterns.")
  else
    TECH_CONTEXT_LINES+=("Architecture patterns were not clearly detected; review manually.")
  fi
  if [[ "$HAS_NETWORKING" == "true" ]]; then TECH_CONTEXT_LINES+=("Networking abstractions are present in source."); fi
  if [[ "$HAS_PUSH_NOTIF" == "true" ]]; then TECH_CONTEXT_LINES+=("Notification or messaging flows are present in source."); fi
  if [[ "$HAS_STORAGE" == "true" ]]; then TECH_CONTEXT_LINES+=("Persistence/session mechanisms are present (UserDefaults/Keychain/CoreData/Realm)."); fi
  if [[ "$HAS_UNIT_TESTS" == "true" && "$HAS_UI_TESTS" == "true" ]]; then
    TECH_CONTEXT_LINES+=("Both unit/integration and UI test targets appear to exist.")
  elif [[ "$HAS_UNIT_TESTS" == "true" ]]; then
    TECH_CONTEXT_LINES+=("At least one test target appears to exist.")
  fi

  PATH_CANDIDATES=()
  for f in README.md docs/architecture.md docs/Architecture.md docs/adr.md Package.swift Podfile Podfile.lock; do
    [[ -f "$REPO_PATH/$f" ]] && PATH_CANDIDATES+=("$f")
  done

  XCODEPROJ_REL="$(find "$REPO_PATH" -maxdepth 3 -name '*.xcodeproj' -type d | head -n 1 | sed "s|$REPO_PATH/||" || true)"
  [[ -n "$XCODEPROJ_REL" ]] && PATH_CANDIDATES+=("$XCODEPROJ_REL")

  COORD_FILE="$(find_first_file_by_pattern "$REPO_PATH" 'Coordinator\.swift$')"
  NOTIF_FILE="$(find_first_file_by_pattern "$REPO_PATH" 'Notification.*\.swift$')"
  APP_FILE="$(find_first_file_by_pattern "$REPO_PATH" '(AppDelegate|SceneDelegate|.*App\.swift)$')"
  VM_FILE="$(find_first_file_by_pattern "$REPO_PATH" 'ViewModel\.swift$')"

  for pf in "$COORD_FILE" "$NOTIF_FILE" "$APP_FILE" "$VM_FILE"; do
    if [[ -n "$pf" ]]; then
      rel="${pf#$REPO_PATH/}"
      PATH_CANDIDATES+=("$rel")
    fi
  done

  declare -A seen_paths
  for p in "${PATH_CANDIDATES[@]}"; do
    [[ -z "$p" ]] && continue
    if [[ -z "${seen_paths[$p]+x}" ]]; then
      CONTEXT_PATHS+=("$p")
      seen_paths[$p]=1
    fi
  done
else
  TECH_CONTEXT_LINES+=("Auto-detection disabled by user.")
fi

mkdir -p "$REPO_PATH/.codex"

CONFIG_FILE="$REPO_PATH/.codex/playbook.config.yml"
AUTO_CONTEXT_FILE="$REPO_PATH/.codex/project_context.auto.md"
AUTO_PATHS_FILE="$REPO_PATH/.codex/project_context_paths.auto.txt"

if [[ -f "$CONFIG_FILE" ]]; then
  cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
fi

{
  echo "version: 1"
  echo "project:"
  echo "  name: \"$PROJECT_NAME\""
  echo "  repo_path: \"$REPO_PATH\""
  echo "  jira_project_key: \"${JIRA_PROJECT_KEY}\""
  echo "integrations:"
  echo "  jira_base_url: \"${JIRA_BASE_URL}\""
  echo "  figma_base_url: \"${FIGMA_BASE_URL}\""
  echo "pipeline:"
  echo "  target_base_branch: \"$BASE_BRANCH\""
  echo "  notify_google_chat: $NOTIFY_GOOGLE_CHAT"
  echo "  auto_detect_context: $AUTO_DETECT_CONTEXT"
  echo "  write_artifacts: $WRITE_ARTIFACTS"
  if [[ "$WRITE_ARTIFACTS" == "true" ]]; then
    echo "  artifacts_path: \"$ARTIFACTS_PATH\""
  fi
  echo "context:"
  echo "  tech_context: |"
  for line in "${TECH_CONTEXT_LINES[@]}"; do
    echo "    $line"
  done
  echo "  project_context_paths:"
  if [[ ${#CONTEXT_PATHS[@]} -eq 0 ]]; then
    echo "    - \"README.md\""
  else
    for p in "${CONTEXT_PATHS[@]}"; do
      echo "    - \"$p\""
    done
  fi
} > "$CONFIG_FILE"

if [[ "$AUTO_DETECT_CONTEXT" == "true" ]]; then
  {
    echo "# Auto-detected Project Context"
    echo
    echo "Generated at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Repository: $REPO_PATH"
    echo
    echo "## Architecture summary"
    for line in "${TECH_CONTEXT_LINES[@]}"; do
      echo "- $line"
    done
    echo
    echo "## Suggested PROJECT_CONTEXT_PATHS"
    if [[ ${#CONTEXT_PATHS[@]} -eq 0 ]]; then
      echo "- README.md"
    else
      for p in "${CONTEXT_PATHS[@]}"; do
        echo "- $p"
      done
    fi
  } > "$AUTO_CONTEXT_FILE"

  if [[ ${#CONTEXT_PATHS[@]} -eq 0 ]]; then
    echo "README.md" > "$AUTO_PATHS_FILE"
  else
    printf "%s\n" "${CONTEXT_PATHS[@]}" > "$AUTO_PATHS_FILE"
  fi
fi

echo "Generated:"
echo "- $CONFIG_FILE"
if [[ "$AUTO_DETECT_CONTEXT" == "true" ]]; then
  echo "- $AUTO_CONTEXT_FILE"
  echo "- $AUTO_PATHS_FILE"
fi
echo
echo "Next:"
echo "Use pipeline-runner with this payload:"
echo "JIRA_KEY: <${JIRA_PROJECT_KEY:-KEY}-123>"
echo "FIGMA_NODE_IDS: <12:34,56:78 or empty>"
echo "RUN_MODE: REAL_RUN"
