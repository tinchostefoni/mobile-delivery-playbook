#!/usr/bin/env bash
set -euo pipefail

if [ -z "${GOOGLE_CHAT_WEBHOOK_URL:-}" ]; then
  echo "GOOGLE_CHAT_WEBHOOK_URL is not set" >&2
  exit 1
fi

TICKET="${1:-UNKNOWN}"
EVENT="${2:-INFO}"
SUMMARY="${3:-No summary provided}"
JIRA_URL="${4:-}"
MR_URL="${5:-}"
ACTION_REQUIRED="${6:-}"

icon="ℹ️"
case "$EVENT" in
  READY_FOR_REVIEW|FINALIZED|SUCCESS|OK|PASSED) icon="✅" ;;
  ERROR_BLOCKING|CI_FAILED|FAIL|FAILED|ERROR) icon="❌" ;;
  ACTION_REQUIRED|CI_PENDING|WARN|WARNING) icon="⚠️" ;;
esac

text="${icon} Pipeline ${TICKET}"
text+=$'\n'"Evento: ${EVENT}"
text+=$'\n'"Resumen: ${SUMMARY}"

if [ -n "$ACTION_REQUIRED" ]; then
  text+=$'\n'"Acción requerida: ${ACTION_REQUIRED}"
fi

if [ -n "$JIRA_URL" ]; then
  text+=$'\n'"Jira: ${JIRA_URL}"
fi

if [ -n "$MR_URL" ]; then
  text+=$'\n'"Merge Request: ${MR_URL}"
fi

payload=$(printf '%s' "$text" | python3 -c 'import json,sys; print(json.dumps({"text": sys.stdin.read()}))')

curl -sS -X POST "$GOOGLE_CHAT_WEBHOOK_URL" \
  -H "Content-Type: application/json; charset=UTF-8" \
  -d "$payload" >/dev/null

echo "Google Chat notification sent"
