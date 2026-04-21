# Bundled Dependencies

This file tracks third-party skills and tools that are shipped directly inside the plugin
rather than installed separately. Each entry includes the source, version, and instructions
for updating to a newer release.

---

## Why bundled?

These dependencies are included as static copies so the plugin is fully self-contained —
no extra install steps for the user, works offline, and produces consistent behavior across
all sessions. The trade-off is that updates are manual.

---

## Bundled skills

These are placed in `skills/` and loaded on-demand by the pipeline's review agents.

| Skill | Bundled version | Commit | Source | Used by | Conditional |
|-------|----------------|--------|--------|---------|-------------|
| `swiftui-pro` | 1.1 | `be297ff` | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) | `code-reviewer` (Gate 3) | When diff contains SwiftUI code |
| `swift-concurrency-pro` | 1.0 | `e710f8d` | [twostraws/Swift-Concurrency-Agent-Skill](https://github.com/twostraws/Swift-Concurrency-Agent-Skill) | `code-reviewer` (Gate 3) | When diff contains async/await or actors |
| `swift-testing-pro` | 1.0 | `3d434c7` | [twostraws/Swift-Testing-Agent-Skill](https://github.com/twostraws/Swift-Testing-Agent-Skill) | `qa-retro` (Gate 5) | When test files are present |
| `swift-architecture-skill` | 0.4.3 | `457f135` | [efremidze/swift-architecture-skill](https://github.com/efremidze/swift-architecture-skill) | `arch-reviewer` (Gate 2) | Always |
| `swift-security-expert` | — | `2a27cb2` | [ivan-magda/swift-security-skill](https://github.com/ivan-magda/swift-security-skill) | `code-reviewer` (Gate 3) | When diff touches Keychain/CryptoKit/auth |
| `figma-to-swiftui` | — | `cc02ca0` | [daetojemax/figma-to-swiftui-skill](https://github.com/daetojemax/figma-to-swiftui-skill) | `figma-intake` | When task is a UI implementation |
| `ios-accessibility` | — | `dcc3a36` | [dadederk/iOS-Accessibility-Agent-Skill](https://github.com/dadederk/iOS-Accessibility-Agent-Skill) | `code-reviewer` (Gate 3), `qa-retro` (Gate 5) | When diff touches accessibility APIs |
| `swiftdata-pro` | 1.0 | `922d989` | [twostraws/SwiftData-Agent-Skill](https://github.com/twostraws/SwiftData-Agent-Skill) | `code-reviewer` (Gate 3), `qa-retro` (Gate 5) | **Only when `pipeline.uses_swiftdata: true` or diff contains `@Model`** |
| `swiftui-ui-patterns` | — | `05ba982` | [Dimillian/Skills](https://github.com/Dimillian/Skills) | `code-reviewer` (Gate 3) | When diff adds/changes SwiftUI navigation, lists, sheets, or tabs |
| `swiftui-performance-audit` | — | `05ba982` | [Dimillian/Skills](https://github.com/Dimillian/Skills) | `code-reviewer` (Gate 3) | When task mentions performance or diff shows heavy `body` computation |
| `swift-api-design-guidelines` | — | `36cdc1b` | [Erikote04/Swift-API-Design-Guidelines-Agent-Skill](https://github.com/Erikote04/Swift-API-Design-Guidelines-Agent-Skill) | `naming-reviewer` (Gate 3) | Always |
| `core-data-expert` | — | `855ca7d` | [AvdLee/Core-Data-Agent-Skill](https://github.com/AvdLee/Core-Data-Agent-Skill) | `code-reviewer` (Gate 3), `qa-retro` (Gate 5) | **Only when `pipeline.uses_coredata: true` or diff contains `NSManagedObject`** |

All licenses are MIT.

> **Note on `swift-security-expert`, `figma-to-swiftui`, and `ios-accessibility`**: these repos
> do not publish a semver version in their `SKILL.md` or `plugin.json`. The commit hash is the
> version identifier. Check upstream for updates using the script below.

---

## MCP servers (not bundled — fetched at runtime)

These are not bundled files. They run on demand via `npx` and always pull the latest
published version from npm unless pinned.

| Server | Config key | Package | Notes |
|--------|-----------|---------|-------|
| Apple Docs | `apple-docs` | [`@kimsungwhee/apple-docs-mcp`](https://github.com/kimsungwhee/apple-docs-mcp) | Pinning: change `"-y"` to `"-y", "@kimsungwhee/apple-docs-mcp@<version>"` in `.claude/settings.json` and `.mcp.json` |

---

## How to update a bundled skill

### One skill at a time

```bash
# 1. Clone the source repo (shallow is enough)
git clone --depth=1 <source-repo-url> /tmp/<skill-name>

# 2. Copy SKILL.md and references/ into the plugin
PLUGIN_ROOT=/path/to/mobile-delivery-playbook
SKILL=<skill-dir-name>   # e.g. swiftui-pro

cp /tmp/<skill-name>/<skill-dir>/<SKILL.md> "$PLUGIN_ROOT/skills/$SKILL/"
cp /tmp/<skill-name>/<skill-dir>/references/*.md "$PLUGIN_ROOT/skills/$SKILL/references/"

# 3. Get the new commit hash
cd /tmp/<skill-name> && git rev-parse --short HEAD

# 4. Update the version and commit in this file (BUNDLED.md)

# 5. Clean up
rm -rf /tmp/<skill-name>
```

### All skills at once

```bash
PLUGIN_ROOT=/path/to/mobile-delivery-playbook

# SwiftUI Pro
git clone --depth=1 https://github.com/twostraws/SwiftUI-Agent-Skill.git /tmp/swiftui-skill
cp /tmp/swiftui-skill/swiftui-pro/SKILL.md "$PLUGIN_ROOT/skills/swiftui-pro/"
cp /tmp/swiftui-skill/swiftui-pro/references/*.md "$PLUGIN_ROOT/skills/swiftui-pro/references/"

# Swift Concurrency Pro
git clone --depth=1 https://github.com/twostraws/Swift-Concurrency-Agent-Skill.git /tmp/concurrency-skill
cp /tmp/concurrency-skill/swift-concurrency-pro/SKILL.md "$PLUGIN_ROOT/skills/swift-concurrency-pro/"
cp /tmp/concurrency-skill/swift-concurrency-pro/references/*.md "$PLUGIN_ROOT/skills/swift-concurrency-pro/references/"

# Swift Testing Pro
git clone --depth=1 https://github.com/twostraws/Swift-Testing-Agent-Skill.git /tmp/testing-skill
cp /tmp/testing-skill/swift-testing-pro/SKILL.md "$PLUGIN_ROOT/skills/swift-testing-pro/"
cp /tmp/testing-skill/swift-testing-pro/references/*.md "$PLUGIN_ROOT/skills/swift-testing-pro/references/"

# Swift Architecture
git clone --depth=1 https://github.com/efremidze/swift-architecture-skill.git /tmp/arch-skill
cp /tmp/arch-skill/swift-architecture-skill/SKILL.md "$PLUGIN_ROOT/skills/swift-architecture-skill/"
cp /tmp/arch-skill/swift-architecture-skill/references/*.md "$PLUGIN_ROOT/skills/swift-architecture-skill/references/"

# Swift Security Expert
git clone --depth=1 https://github.com/ivan-magda/swift-security-skill.git /tmp/security-skill
cp /tmp/security-skill/swift-security-expert/SKILL.md "$PLUGIN_ROOT/skills/swift-security-expert/"
cp /tmp/security-skill/swift-security-expert/references/*.md "$PLUGIN_ROOT/skills/swift-security-expert/references/"

# Figma to SwiftUI
git clone --depth=1 https://github.com/daetojemax/figma-to-swiftui-skill.git /tmp/figma-swiftui-skill
cp /tmp/figma-swiftui-skill/SKILL.md "$PLUGIN_ROOT/skills/figma-to-swiftui/"
cp /tmp/figma-swiftui-skill/references/*.md "$PLUGIN_ROOT/skills/figma-to-swiftui/references/"

# iOS Accessibility
git clone --depth=1 https://github.com/dadederk/iOS-Accessibility-Agent-Skill.git /tmp/a11y-skill
cp /tmp/a11y-skill/ios-accessibility/SKILL.md "$PLUGIN_ROOT/skills/ios-accessibility/"
cp /tmp/a11y-skill/ios-accessibility/references/*.md "$PLUGIN_ROOT/skills/ios-accessibility/references/"

# SwiftData Pro
git clone --depth=1 https://github.com/twostraws/SwiftData-Agent-Skill.git /tmp/swiftdata-skill
cp /tmp/swiftdata-skill/swiftdata-pro/SKILL.md "$PLUGIN_ROOT/skills/swiftdata-pro/"
cp /tmp/swiftdata-skill/swiftdata-pro/references/*.md "$PLUGIN_ROOT/skills/swiftdata-pro/references/"

# SwiftUI UI Patterns + SwiftUI Performance Audit (same repo)
git clone --depth=1 https://github.com/Dimillian/Skills.git /tmp/dimillian-skills
cp /tmp/dimillian-skills/swiftui-ui-patterns/SKILL.md "$PLUGIN_ROOT/skills/swiftui-ui-patterns/"
cp /tmp/dimillian-skills/swiftui-ui-patterns/references/*.md "$PLUGIN_ROOT/skills/swiftui-ui-patterns/references/"
cp /tmp/dimillian-skills/swiftui-performance-audit/SKILL.md "$PLUGIN_ROOT/skills/swiftui-performance-audit/"
cp /tmp/dimillian-skills/swiftui-performance-audit/references/*.md "$PLUGIN_ROOT/skills/swiftui-performance-audit/references/"

# Swift API Design Guidelines
git clone --depth=1 https://github.com/Erikote04/Swift-API-Design-Guidelines-Agent-Skill.git /tmp/api-guidelines-skill
cp /tmp/api-guidelines-skill/swift-api-design-guidelines-skill/SKILL.md "$PLUGIN_ROOT/skills/swift-api-design-guidelines/"
cp /tmp/api-guidelines-skill/swift-api-design-guidelines-skill/references/*.md "$PLUGIN_ROOT/skills/swift-api-design-guidelines/references/"

# Core Data Expert
git clone --depth=1 https://github.com/AvdLee/Core-Data-Agent-Skill.git /tmp/coredata-skill
cp /tmp/coredata-skill/core-data-expert/SKILL.md "$PLUGIN_ROOT/skills/core-data-expert/"
cp /tmp/coredata-skill/core-data-expert/references/*.md "$PLUGIN_ROOT/skills/core-data-expert/references/"

# Print commit hashes for BUNDLED.md update
for entry in \
  "swiftui-skill swiftui-pro" \
  "concurrency-skill swift-concurrency-pro" \
  "testing-skill swift-testing-pro" \
  "arch-skill swift-architecture-skill" \
  "security-skill swift-security-expert" \
  "figma-swiftui-skill figma-to-swiftui" \
  "a11y-skill ios-accessibility" \
  "swiftdata-skill swiftdata-pro" \
  "dimillian-skills swiftui-ui-patterns+swiftui-performance-audit" \
  "api-guidelines-skill swift-api-design-guidelines" \
  "coredata-skill core-data-expert"; do
  read -r dir skill <<< "$entry"
  echo "$skill: $(cd /tmp/$dir && git rev-parse --short HEAD)"
done

# Clean up
rm -rf /tmp/swiftui-skill /tmp/concurrency-skill /tmp/testing-skill /tmp/arch-skill \
       /tmp/security-skill /tmp/figma-swiftui-skill /tmp/a11y-skill /tmp/swiftdata-skill \
       /tmp/dimillian-skills /tmp/api-guidelines-skill /tmp/coredata-skill
```

After running, update the commit hashes and versions in the table above, then commit:

```
chore(bundled): update swift skills to latest
```

---

## How to check if a bundled skill is outdated

```bash
# Compare local commit vs. upstream HEAD for each skill
for entry in \
  "be297ff https://github.com/twostraws/SwiftUI-Agent-Skill.git swiftui-pro" \
  "e710f8d https://github.com/twostraws/Swift-Concurrency-Agent-Skill.git swift-concurrency-pro" \
  "3d434c7 https://github.com/twostraws/Swift-Testing-Agent-Skill.git swift-testing-pro" \
  "457f135 https://github.com/efremidze/swift-architecture-skill.git swift-architecture-skill" \
  "2a27cb2 https://github.com/ivan-magda/swift-security-skill.git swift-security-expert" \
  "cc02ca0 https://github.com/daetojemax/figma-to-swiftui-skill.git figma-to-swiftui" \
  "dcc3a36 https://github.com/dadederk/iOS-Accessibility-Agent-Skill.git ios-accessibility" \
  "922d989 https://github.com/twostraws/SwiftData-Agent-Skill.git swiftdata-pro" \
  "05ba982 https://github.com/Dimillian/Skills.git swiftui-ui-patterns" \
  "05ba982 https://github.com/Dimillian/Skills.git swiftui-performance-audit" \
  "36cdc1b https://github.com/Erikote04/Swift-API-Design-Guidelines-Agent-Skill.git swift-api-design-guidelines" \
  "855ca7d https://github.com/AvdLee/Core-Data-Agent-Skill.git core-data-expert"; do
  read -r local_hash url skill <<< "$entry"
  remote_hash=$(git ls-remote "$url" HEAD | cut -f1 | cut -c1-7)
  if [ "$local_hash" = "$remote_hash" ]; then
    echo "$skill: up to date ($local_hash)"
  else
    echo "$skill: OUTDATED — local=$local_hash, remote=$remote_hash"
  fi
done
```

---

*Last updated: 2026-04-21*
