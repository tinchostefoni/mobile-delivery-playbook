# Project-Specific Pending Checklist

These items are intentionally not global and must be defined per project.

1. iOS support matrix per project
- Minimum iOS version
- Target iOS versions for QA

2. Simulator/device matrix per project
- Minimum simulator set aligned with minimum iOS
- Any required real-device checks

3. CI integration finalization per project
- Integrate checks into existing `.gitlab-ci.yml`
- Enforce commit format check
- Enforce MR title format check
- Enforce changelog update under `Unreleased`
- Enforce tests green as merge gate

4. Branch target default per project
- Confirm default target branch (`develop`/`dev`/`development` or release branch policy)
