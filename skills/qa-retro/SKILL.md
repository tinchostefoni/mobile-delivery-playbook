---
name: qa-retro
description: >
  Evaluate implementation outputs, verify merge gates (tests, QA, changelog),
  and produce a qa_result following the qa_result JSON schema.
  Triggers after implementation and testing phases of the pipeline.
allowed-tools: Bash, Read, Write
---

# QA Retro

Use this skill after implementation and testing.

## Input
- `implementation_result.json`
- QA evidence/results
- CI test status

## Output
- `qa_result.json` compliant with `contracts/qa_result.schema.json`

## Skills available

Load the following skills based on what is being reviewed:

| Condition | Load skill |
|-----------|-----------|
| Test code present (any `.swift` file in a `*Tests` target) | **`swift-testing-pro`** — Swift Testing structs, `#expect`/`#require`, async tests, XCTest migration |
| Implementation touches UI or accessibility APIs | **`ios-accessibility`** — validate VoiceOver labels, Dynamic Type, assistive tech compliance |
| `pipeline.uses_swiftdata: true` in config **OR** model changes include `@Model` | **`swiftdata-pro`** — relationships, delete rules, predicate correctness |
| `pipeline.uses_coredata: true` in config **OR** changes include `NSManagedObject` | **`core-data-expert`** — save patterns, threading, migration, persistent history |

## XcodeBuildMCP — simulator QA

If `XcodeBuildMCP` tools are available, run the following sequence and collect real evidence.
Each step produces data that feeds `qa_result.validations`.

### Setup
```
# Verify project config is set (use session_set_defaults if missing)
session_show_defaults()

# Ensure simulator is running
boot_sim()
```

### Build + test (mandatory)
```
# Re-compile to confirm nothing broke between dev-executor and QA
build_sim()

# Run full test suite — capture pass/fail and xcresult path from output
test_sim()
```

- If `build_sim` fails → set `all_tests_green: false`, `mergeable: false`, `recommendation: blocked`.
- If any test fails → set `all_tests_green: false`, `mergeable: false`, `recommendation: blocked`.
- Parse `test_sim` output for the `xcresult` bundle path (emitted as `Build/Derived/.../test.xcresult`).

### Coverage (when xcresult path is available)
```
get_coverage_report(xcresultPath: "<path-from-test_sim>", showFiles: true)
```

Record the overall coverage % and per-file breakdown in `qa_result.validations.coverage`.

### Visual evidence (when task is UI-related)
```
# Launch app and capture startup logs — detects launch crashes
launch_app_logs_sim()

# Grab a screenshot of the implemented screen
screenshot(returnFormat: "base64")

# Capture view hierarchy for accessibility and structural verification
snapshot_ui()
```

Store screenshot and snapshot as evidence references in `qa_result.validations.screenshots`.

### When XcodeBuildMCP is unavailable
Document each skipped step in `qa_result.validations` as `"step": "skipped — XcodeBuildMCP not available"`.
`all_tests_green` MUST be set to `false` unless the user explicitly provides CI green evidence
from another source.

## Workflow
1. Run XcodeBuildMCP simulator sequence (see above) — collect build, test, coverage, and visual evidence.
2. Load conditional skills based on what the implementation touches (see Skills available above).
3. Validate checks and regressions against `implementation_result` and the collected evidence.
4. Set merge gates:
   - `all_tests_green` — true only if `build_sim` passed AND `test_sim` reported 0 failures
   - `qa_approved` — true only if no blocking issues found by code-reviewer or naming-reviewer
   - `changelog_updated` — true only if `CHANGELOG.md` has an entry under `[Unreleased]`
5. Set `mergeable: true` only if all three gates are true.
6. Provide clear recommendation (`ready_for_review`, `needs_changes`, or `blocked`).
7. Validate output against `contracts/qa_result.schema.json` using `$PLAYBOOK_ROOT/scripts/validate_contract.sh` when available.

## Constraints
- If any test fails, block. No exceptions.
- Build failure blocks even if tests were previously green.
- QA approval does not replace CI green status — it is a complementary gate.
- `mergeable: true` is never set based on declared evidence alone — it requires actual
  XcodeBuildMCP output or explicit user-provided CI evidence.
