#!/usr/bin/env bash
# build_plugin.sh — package the mobile-delivery-playbook as a .plugin file
# Usage: bash scripts/build_plugin.sh [output-path]
# Default output: dist/mobile-delivery-playbook-<version>.plugin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
PLUGIN_NAME="mobile-delivery-playbook"

# Extract version from plugin.json
VERSION=$(grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version": *"\([^"]*\)".*/\1/')
echo "Building $PLUGIN_NAME v$VERSION..."

OUTPUT_FILE="${1:-$REPO_ROOT/dist/${PLUGIN_NAME}-${VERSION}.plugin}"
mkdir -p "$(dirname "$OUTPUT_FILE")"

TMP_PLUGIN="/tmp/${PLUGIN_NAME}.plugin"

# Package from repo root — exclude non-distributable paths
cd "$REPO_ROOT"
zip -r "$TMP_PLUGIN" . \
  -x "*.git/*" \
  -x "*.git" \
  -x "*.DS_Store" \
  -x "engram/*" \
  -x "dist/*" \
  -x ".env.playbook" \
  -x ".playbook/*" \
  -x "*.plugin"

cp "$TMP_PLUGIN" "$OUTPUT_FILE"
rm -f "$TMP_PLUGIN"

echo "Done: $OUTPUT_FILE"
echo ""
echo "To install locally:"
echo "  claude plugin install $OUTPUT_FILE"
echo ""
echo "To publish (GitHub Release):"
echo "  gh release create v$VERSION $OUTPUT_FILE --title \"v$VERSION\" --notes \"See CHANGELOG.md\""
