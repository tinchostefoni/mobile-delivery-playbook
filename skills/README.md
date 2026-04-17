# Bundled Skills

This folder contains the pipeline skills required by this playbook:

| Skill | Purpose |
|-------|---------|
| `playbook-setup` | One-time project initialization — creates `.playbook/playbook.config.yml` in the target repo |
| `pipeline-runner` | Orchestrates the full pipeline for a single Jira ticket |
| `jira-intake` | Reads a Jira issue and produces `ticket_spec.json` |
| `figma-intake` | Extracts design context from Figma and produces `design_spec.json` |
| `spec-filler` | Combines ticket + design specs into an `implementation_brief.json` |
| `dev-executor` | Implements the brief and produces `implementation_result.json` |
| `qa-retro` | Validates implementation against the brief and produces `qa_result.json` |

## Install

### Option A — Plugin (recommended)

```bash
claude plugin marketplace add tinchostefoni/mobile-delivery-playbook
claude plugin install mobile-delivery-playbook
```

Skills are available in any Cowork session after install.
Update when a new version is released:
```bash
claude plugin update mobile-delivery-playbook
```

### Option B — Cowork folder (development mode)

Clone the repo and open it as the selected folder in Cowork. No install needed — Claude loads the skills directly from the folder.

### Option C — Manual install (Claude Code CLI)

```bash
bash scripts/install_skills.sh
```

Copies skills to `~/.claude/skills/`. Restart Claude Code to reload.

## Building a new plugin version

After making changes to the playbook, package a new `.plugin` release:

```bash
# Bump version in .claude-plugin/plugin.json first, then:
bash scripts/build_plugin.sh
# Output: dist/mobile-delivery-playbook-<version>.plugin

# Publish to GitHub:
gh release create v<version> dist/mobile-delivery-playbook-<version>.plugin \
  --title "v<version>" --notes "See CHANGELOG.md"
```

## References
- Workflow: [workflow.md](../workflow.md)
- Standards: [mobile-gitlab-standard.md](../mobile-gitlab-standard.md)
- Contracts: [contracts/README.md](../contracts/README.md)
- Technical guide: [technical-reference.md](../technical-reference.md)
