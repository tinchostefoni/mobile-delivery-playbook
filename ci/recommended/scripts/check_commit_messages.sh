#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CI_MERGE_REQUEST_TARGET_BRANCH_SHA:-}" || -z "${CI_COMMIT_SHA:-}" ]]; then
  echo "Missing MR commit range environment variables."
  exit 1
fi

pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)\([^)]+\): \[[A-Z]+-[0-9]+\] .+'

fail=0
while IFS= read -r msg; do
  [[ -z "$msg" ]] && continue
  if ! [[ "$msg" =~ $pattern ]]; then
    echo "Invalid commit message: $msg"
    fail=1
  fi
  if (( ${#msg} > 100 )); then
    echo "Commit message too long (>100): $msg"
    fail=1
  fi
done < <(git log --format=%s "${CI_MERGE_REQUEST_TARGET_BRANCH_SHA}..${CI_COMMIT_SHA}")

if [[ $fail -ne 0 ]]; then
  exit 1
fi

echo "Commit message check passed."
