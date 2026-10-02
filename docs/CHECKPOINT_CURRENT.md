# CURRENT CHECKPOINT

VeilLink **26.9 (Build 55)** is the cumulative recovery checkpoint. Build 55 adds the
P0 legal-consent input-focus crash fix while preserving the complete Build 54 recovery line.

The branch is based on the complete 26.9 Build 53 formal-release tree and carries
the I12/A10 Ultra M5 overlay plus the subsequent compile and release-gate fixes.
It retains the formal release features that were accidentally removed when the
I12 update package was materialized over the older V0.9.7 tree, including voice/PTT,
LAN transport, remote pairing, Tool Center, background continuity/widget support,
legal/onboarding, relay/community code, native game bots, and the full test suite.

A10 Ultra Ω OMEGA 96 is now available as a formal, independent governance path:
it consumes raw host health facts and may author the shared compute-budget contract,
while transport, storage, identity, game and tool mutation authority remain host-owned.
Runtime failure immediately falls back to A9. The separate A10 Ultra M5 inference
assets remain a trained **shadow** path with SHA-256-pinned resources and
`production_cutover: DENY`; no unvalidated M5 capability is promoted. Raw training
carriers (`weights.npz`, `brain.npz`) and other heavy experimental resources remain
forbidden from the Core IPA.

Release invariants are enforced by `scripts/verify-recovery-lineage.py` and
`scripts/verify-core-release.py`. The app and widget inherit version/build values
from `project.yml`; no source Info.plist may hardcode V0.9.7 again.
