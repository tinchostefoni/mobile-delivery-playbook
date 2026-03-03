# Bundled Skills

This folder contains the pipeline skills required by this playbook:

- `playbook-setup`
- `jira-intake`
- `figma-intake`
- `spec-filler`
- `dev-executor`
- `qa-retro`
- `pipeline-runner`

## Install (local user)

Run from this repository root:

```bash
bash scripts/install_skills.sh
```

The script copies these skills into `~/.playbook/skills/`.

After install, restart Claude Code so skills are reloaded.

## References
- Workflow: [workflow.md](workflow.md)
- Technical guide: [technical-reference.md](technical-reference.md)
