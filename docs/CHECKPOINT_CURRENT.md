# CURRENT CHECKPOINT

VeilLink **26.9 (Build 55)** is the cumulative recovery checkpoint. Build 55 adds the
P0 legal-consent input-focus crash fix while preserving the complete Build 54 recovery line.

The branch is based on the complete 26.9 Build 53 formal-release tree and carries
the I12/A10 Ultra M5 overlay plus the subsequent compile and release-gate fixes.
It retains the formal release features that were accidentally removed when the
I12 update package was materialized over the older V0.9.7 tree, including voice/PTT,
LAN transport, remote pairing, Tool Center, background continuity/widget support,
legal/onboarding, relay/community code, native game bots, and the full test suite.

A10 Ultra M5 remains a trained **shadow** cognition/governance path. Its compact
iOS resources are SHA-256 pinned; `production_cutover` remains `DENY`. Raw training
carriers (`weights.npz`, `brain.npz`) and other heavy experimental resources are
forbidden from the Core IPA. A9 remains available as the stable primary path.

Release invariants are enforced by `scripts/verify-recovery-lineage.py` and
`scripts/verify-core-release.py`. The app and widget inherit version/build values
from `project.yml`; no source Info.plist may hardcode V0.9.7 again.
