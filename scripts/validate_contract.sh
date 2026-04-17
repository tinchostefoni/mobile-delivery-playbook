#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/validate_contract.sh --schema <path-to-schema.json> --data <path-to-data.json>
  bash scripts/validate_contract.sh --schema <path-to-schema.json> --data-stdin

Validates a JSON artifact against its JSON Schema.

Options:
  --schema <path>     Path to JSON Schema file (required)
  --data <path>       Path to JSON data file
  --data-stdin        Read JSON data from stdin
  --output-format <text|json>  Default: text
  -h, --help          Show this help

Exit codes:
  0  validation passed
  1  validation failed
  2  usage/input error
EOF
}

SCHEMA_PATH=""
DATA_PATH=""
DATA_STDIN="false"
OUTPUT_FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema) SCHEMA_PATH="${2:-}"; shift 2 ;;
    --data) DATA_PATH="${2:-}"; shift 2 ;;
    --data-stdin) DATA_STDIN="true"; shift ;;
    --output-format) OUTPUT_FORMAT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$SCHEMA_PATH" ]] || { echo "ERROR: --schema is required" >&2; exit 2; }
[[ -f "$SCHEMA_PATH" ]] || { echo "ERROR: Schema file not found: $SCHEMA_PATH" >&2; exit 2; }

if [[ "$DATA_STDIN" == "true" ]]; then
  TMP_DATA="$(mktemp)"
  cat > "$TMP_DATA"
  DATA_PATH="$TMP_DATA"
elif [[ -n "$DATA_PATH" ]]; then
  [[ -f "$DATA_PATH" ]] || { echo "ERROR: Data file not found: $DATA_PATH" >&2; exit 2; }
else
  echo "ERROR: --data or --data-stdin is required" >&2
  exit 2
fi

# Validate JSON syntax first
python3 -c "import json; json.load(open('$DATA_PATH'))" 2>/dev/null || {
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo '{"status":"fail","error":"Invalid JSON syntax in data"}'
  else
    echo "VALIDATION_FAIL: Invalid JSON syntax in data" >&2
  fi
  exit 1
}

# Validate against schema
python3 - "$SCHEMA_PATH" "$DATA_PATH" "$OUTPUT_FORMAT" <<'PY'
import json, sys

schema_path = sys.argv[1]
data_path = sys.argv[2]
output_format = sys.argv[3]

with open(schema_path) as f:
    schema = json.load(f)
with open(data_path) as f:
    data = json.load(f)

try:
    import jsonschema
    validator = jsonschema.Draft7Validator(schema)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path))
    if errors:
        if output_format == "json":
            err_list = []
            for e in errors:
                err_list.append({
                    "path": ".".join(str(p) for p in e.absolute_path) or "(root)",
                    "message": e.message
                })
            print(json.dumps({"status": "fail", "errors": err_list}))
        else:
            for e in errors:
                path = ".".join(str(p) for p in e.absolute_path) or "(root)"
                print(f"VALIDATION_FAIL [{path}]: {e.message}", file=sys.stderr)
        sys.exit(1)
    else:
        if output_format == "json":
            print(json.dumps({"status": "ok", "errors": []}))
        else:
            print("VALIDATION_OK: Contract is schema-compliant")
        sys.exit(0)

except ImportError:
    # Fallback: basic structural validation without jsonschema library
    required = schema.get("required", [])
    missing = [k for k in required if k not in data]

    if missing:
        if output_format == "json":
            err_list = [{"path": m, "message": f"Missing required field: {m}"} for m in missing]
            print(json.dumps({"status": "fail", "errors": err_list, "note": "basic validation only (install jsonschema for full validation)"}))
        else:
            for m in missing:
                print(f"VALIDATION_FAIL [{m}]: Missing required field", file=sys.stderr)
            print("NOTE: Install jsonschema (pip install jsonschema) for full schema validation", file=sys.stderr)
        sys.exit(1)
    else:
        if output_format == "json":
            print(json.dumps({"status": "ok", "errors": [], "note": "basic validation only (install jsonschema for full validation)"}))
        else:
            print("VALIDATION_OK: Basic structure check passed (install jsonschema for full validation)")
        sys.exit(0)
PY
