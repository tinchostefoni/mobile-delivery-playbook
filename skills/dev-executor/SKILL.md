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

## Workflow
1. **Arch guard** — before writing any file, cross-check every `work_item` in `implementation_brief`
   against the project architecture. If any item touches layers, modules, or dependency edges
   not declared in the brief:
   - STOP execution immediately.
   - Output a numbered list of the out-of-scope items with a one-line rationale each.
   - Wait for explicit user approval for each item before proceeding.
   - Do not proceed until all out-of-scope items are either approved or removed from scope.
2. Implement `work_items` incrementally, strictly within the approved scope.
3. Run required tests/checks.
4. Update `CHANGELOG.md` under `[Unreleased]` from real code diff — see format rules below.
5. Capture validation evidence and changed files.
6. Fill `implementation_result.changelog` fields.
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
