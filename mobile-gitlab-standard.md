# Mobile GitLab Standard v1.0 (Global)

Status: global rules closed

## 1) Commit message standard

Base format:
`<type>(<scope>): <short description>`

Example:
`fix(networking): corrigió el reintento ante timeout en login`

Mandatory rules:
- `type` is required.
- `scope` is required.
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
- `PROJECT-123-fix-login-timeout-retry`
- `PROJECT-456-feature-self-exclusion-flow`

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
`[PROJECT-123] fix: corrigió el reintento ante timeout en login`

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
```

## 5) Changelog policy

Format standard: Keep a Changelog 1.1.0.

### Placement
- New entries go under `## [Unreleased]` only.
- Never write entries under a versioned section (e.g. `## [1.2.0]`).
- Changelog must be updated **before** `EFFECTIVIZE_COMMIT` is issued.

### Entry format
```
### <Section>
- <PastTenseVerb> <component/file>: <what changed>
```

- One line per logical change. Max 100 chars per line.
- Language: technical. No natural language paragraphs. No explanatory sentences.
- Verb must be past tense and specific: `Fixed`, `Added`, `Removed`, `Refactored`, `Replaced`,
  `Extracted`, `Renamed`, `Updated`, `Migrated`, `Exposed`, `Disabled`.
- Component/file reference is mandatory. Do not write generic entries.

### Allowed sections
`Added`, `Changed`, `Fixed`, `Removed`, `Security`

Prohibited: `Updated` as a section name. `Updated` is allowed as a verb inside entries.

### Good examples
```markdown
### Fixed
- Fixed `SessionManager` token refresh race condition on concurrent requests
- Removed redundant `viewDidAppear` override in `ProfileViewController`

### Changed
- Replaced `UIAlertController` with `CustomBottomSheet` in logout confirmation flow
- Renamed `UserModel.id` to `UserModel.userId` for consistency with API contract

### Added
- Exposed `DeviceRegistrationUseCase` through `DependencyContainer`
```

### Bad examples (prohibited)
```markdown
### Changed
- Se realizaron mejoras en el módulo de autenticación para solucionar
  un problema que afectaba a los usuarios al intentar cerrar sesión.

### Updated
- Authentication improvements

### Fixed
- Fixed bugs
```

### Validation rules (enforced by Gate 4)
- `## [Unreleased]` section must exist and have new entries after the last commit.
- Each entry must start with `-` followed by a past-tense verb.
- No entry may exceed 100 characters.
- No entry may contain more than one sentence.
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

- No automatic commits by agent — requires explicit `EFFECTIVIZE_COMMIT` command.
- No automatic push by agent — requires explicit user command.
- No automatic merge by agent — always manual.
- Changelog must be updated before `EFFECTIVIZE_COMMIT` is accepted.
- Changelog entries must follow section 5 format rules — no natural language, no paragraphs.
- Agent only proposes commit/MR/changelog content; user triggers execution.