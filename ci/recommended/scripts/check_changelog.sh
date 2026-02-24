#!/usr/bin/env bash
set -euo pipefail

CHANGELOG_PATH="CHANGELOG.md"

if [[ ! -f "$CHANGELOG_PATH" ]]; then
  echo "CHANGELOG.md not found at repo root."
  exit 1
fi

if [[ -z "${CI_MERGE_REQUEST_TARGET_BRANCH_SHA:-}" || -z "${CI_COMMIT_SHA:-}" ]]; then
  echo "Missing MR commit range environment variables."
  exit 1
fi

if ! git diff --name-only "${CI_MERGE_REQUEST_TARGET_BRANCH_SHA}..${CI_COMMIT_SHA}" | grep -q "^${CHANGELOG_PATH}$"; then
  echo "CHANGELOG.md must be updated for code changes."
  exit 1
fi

if ! grep -q '^## \[Unreleased\]' "$CHANGELOG_PATH"; then
  echo "CHANGELOG.md must contain '## [Unreleased]' section."
  exit 1
fi

if grep -q '^## Updated$' "$CHANGELOG_PATH"; then
  echo "Section 'Updated' is not allowed. Use 'Changed'."
  exit 1
fi

echo "Changelog check passed."
