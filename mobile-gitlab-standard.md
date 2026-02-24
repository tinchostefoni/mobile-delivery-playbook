# Mobile GitLab Standard v1.0 (Global)

Status: global rules closed

## 1) Commit message standard

Base format:
`<type>(<scope>): [<ISSUE-ID>] <short description>`

Example:
`fix(networking): [LSF-649] corrigió el reintento ante timeout en login`

Mandatory rules:
- `type` is required.
- `scope` is required.
- Jira ticket is required: `[<ISSUE-ID>]`.
- Short description must be clear and concise.
- Max header length: 100 chars.

Allowed types:
- `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

Scope policy:
- Scope must match a real app module/feature or shared abstraction layer.
- Examples: `auth`, `devices`, `permissionLinking`, `networking`, `schemes`, `project`.
- Valid scopes are project-specific and evolve with the codebase.

Breaking change:
- Format: `<type>(<scope>)!: [<ISSUE-ID>] <desc>`
- Add body line: `BREAKING CHANGE: ...`

## 2) Branch naming and base policy

Branch name format:
`<ISSUE-ID>-<kind>-<short-kebab-description>`

Kinds:
- `feature`, `fix`, `hotfix`, `chore`

Examples:
- `LSF-649-fix-login-timeout-retry`
- `LSF-673-feature-self-exclusion-flow`

Before creating any new branch, always:
1. Checkout base branch (`dev`, `develop`, or `development`, depending on project).
2. Run `git pull -r`.
3. Create the working branch.

Additional safeguards:
- Validate upstream/tracking before `pull -r`.
- If base branch has uncommitted local changes, stop and resolve first.

## 3) Merge Request policy

Merge rules:
- Merge is always manual (never automated by agent).
- Squash is mandatory for every MR.
- GitLab pipelines are blocking.
- Minimum approvals required: 1.

Testing gates:
- If any test fails, MR is blocked.
- QA approval does not replace CI; tests must also pass in CI.
- MR is mergeable only when tests are green and QA is approved.

MR title format (mandatory):
`[<ISSUE-ID>] <type>: <short explanation>`

Example:
`[LSF-649] fix: corrigió el reintento ante timeout en login`

Allowed MR types:
- `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

Notes:
- MR `type` can differ from individual commit types.
- MR `type` must describe the dominant change of the MR.

## 4) Merge Request description template

Use this exact structure:

```md
### Summary
Breve descripción del cambio en 1–2 líneas.

### Changes
- Punto clave 1.
- Punto clave 2.
- Punto clave 3.

### Testing Steps
1. Abrir la app y navegar a <pantalla>.
2. Ejecutar <acción> y verificar <resultado>.

### Changelog
- [ ] Actualizado `CHANGELOG.md` en `Unreleased` siguiendo Keep a Changelog.
```

## 5) Changelog policy

- Changelog must follow Keep a Changelog 1.1.0.
- New entries go under `## [Unreleased]`.
- Every code change must be represented.
- Entries must be based on real code diff and verified behavior, not Jira ticket wording.
- Use past tense in all entries.
- Allowed sections: `Added`, `Changed`, `Fixed`, `Removed`, `Security`.
- `Updated` must not be used.
- "No changelog required" is not valid when code changed.

## 6) Testing policy (global)

- Supported iOS versions are defined per project.
- Minimum devices/simulators must align with project minimum iOS.
- Unit tests are mandatory for module/feature development, following existing project patterns.
- Integration/UI tests must run according to each project's existing suite.
- For fixes/changes, relevant tests must run and pass before QA.
- Flaky tests are not accepted; they must be fixed.
- If project/module has no tests for a fix/change, creating new tests is not mandatory.

## 7) Non-negotiables for agent workflow

- No automatic commits by agent.
- No automatic push by agent.
- No automatic merge by agent.
- Agent only proposes commit/MR/changelog content.