# CHECKPOINT · Tactical V2 B-04B

Base repository: `Righteous1776/VeilLink`
Base branch: `main`
Verified base commit: `ee716e1e91719225e7e740724ac551bc4eeb7acb`

## What this overlay adds

- `VeilLink/Core/TacticalV2/*.swift`
- `VeilLink/UI/TacticalV2/*.swift`
- `VeilLink/Resources/Tactical/guandu_large_map_v2_48x27.json`
- `VeilLinkTests/TacticalV2Tests.swift`
- `scripts/validate-tactical-v2.sh`

The current `project.yml` already recursively includes `VeilLink` and
`VeilLinkTests`, so no project-file mutation is required.

Legacy `TacticalBoardView` remains untouched. Existing VLGM1/7×9 sessions must
continue to use the old view until Tactical Wire V2 session plumbing is integrated.

## GitHub write gate

Attempted branch:
`feature/tactical-v2-b04b`

Result:
`403 Resource not accessible by integration`

No write to `main` was attempted.

After repository write/ref permission is available, apply this overlay to an isolated
branch and run:

```bash
bash scripts/validate-tactical-v2.sh
```
