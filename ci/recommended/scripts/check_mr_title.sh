#!/usr/bin/env bash
set -euo pipefail

title="${CI_MERGE_REQUEST_TITLE:-}"
if [[ -z "$title" ]]; then
  echo "CI_MERGE_REQUEST_TITLE is empty."
  exit 1
fi

pattern='^\[[A-Z]+-[0-9]+\] (feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert): .+'

if ! [[ "$title" =~ $pattern ]]; then
  echo "Invalid MR title format: $title"
  echo "Expected: [ISSUE-ID] <type>: <short explanation>"
  exit 1
fi

echo "MR title check passed."
