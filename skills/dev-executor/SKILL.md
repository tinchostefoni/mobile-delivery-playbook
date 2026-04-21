---
name: dev-executor
description: >
  Implement code changes from an implementation_brief and produce an
  implementation_result with validations and changelog evidence.
  Triggers during the implementation phase of the pipeline.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Dev Executor

Use this skill for implementation execution.

## Input
- `implementation_brief.json`

## Output
- Code changes
- `implementation_result.json` compliant with `contracts/implementation_result.schema.json`

## XcodeBuildMCP — compilation gate

If `XcodeBuildMCP` tools are available, use them to verify the build compiles after implementation:

```
# 1. Confirm project is configured (no-op if already set up)
session_show_defaults()

# 2. If defaults are missing, discover the project first
discover_projs(workspaceRoot: <REPO_PATH>)
# Then set defaults:
session_set_defaults(workspacePath|projectPath, scheme, simulatorName)

# 3. Compile — MUST succeed before producing implementation_result
build_sim()
```

If `build_sim` fails:
- Do NOT produce `implementation_result.json`.
- Show the compiler errors in full.
- Fix them and re-run `build_sim` until it passes.
- Only then proceed to produce `implementation_result.json`.

If `XcodeBuildMCP` is not available, document this in `implementation_result.validations`
as `"xcode_build": "skipped — XcodeBuildMCP not available"`.

## Workflow
1. **Arch guard** — before writing any file, cross-check every `work_item` in `implementation_brief`
   against the project architecture. If any item touches layers, modules, or dependency edges
   not declared in the brief:
   - STOP execution immediately.
   - Output a numbered list of the out-of-scope items with a one-line rationale each.
   - Wait for explicit user approval for each item before proceeding.
   - Do not proceed until all out-of-scope items are either approved or removed from scope.
2. Implement `work_items` incrementally, strictly within the approved scope.
3. **Compilation gate** — run `build_sim()` via XcodeBuildMCP (see section above). Do not
   continue if the build fails.
4. Update `CHANGELOG.md` under `[Unreleased]` from real code diff — see format rules below.
5. Capture validation evidence and changed files.
6. Fill `implementation_result.changelog` fields. Include `build_sim` result in validations.
7. Validate output against `contracts/implementation_result.schema.json` using
   `$PLAYBOOK_ROOT/scripts/validate_contract.sh` when available.

## Changelog format rules (mandatory)
- Entry location: `## [Unreleased]` section only. Never under a versioned section.
- Language: technical, not natural. No paragraphs.
- Format per entry: `- <PastTenseVerb> <component/file>: <what changed>` — one line, max 100 chars.
- Allowed Keep a Changelog subsections: `Added`, `Changed`, `Fixed`, `Removed`, `Security`.
- One entry per logical change. Do not group unrelated changes into one line.

Good examples:
```
### Fixed
- Fixed `AuthCoordinator` missing `weak self` in session expiry closure
- Removed duplicate `UserDefaults` write on logout path

### Changed
- Refactored `AvatarView` layout to use `LazyVStack` instead of nested `VStack`
```

Bad examples (do not use):
```
### Changed
- Se realizaron mejoras en el módulo de autenticación para corregir un problema
  que afectaba a los usuarios al cerrar sesión en ciertos dispositivos.
```

## Constraints
- Implement only what is declared in `implementation_brief`. Any deviation requires explicit
  user approval obtained during the arch guard step (step 1).
- Never auto-commit, auto-push, or auto-merge. Commit only after explicit `EFFECTIVIZE_COMMIT`
  command from the user.
- Changelog must be updated before the user issues `EFFECTIVIZE_COMMIT`.
