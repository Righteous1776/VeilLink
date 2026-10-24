# CURRENT CHECKPOINT

VeilLink **26.14 (Build 60)** is the comprehensive **integration candidate** based on the verified Build 59 release. It now contains Inbox #49–#58 selected product patches, including #56 Wire v4-compatible R1–R5 and SQLite v8→v9→v10 migration. Protocol version remains 4; signed optional Hello capabilities, encrypted control events, receipts and durable per-recipient outbox are added only with current-session authenticated negotiation. #53's competing *plan* does not create a second schema.

Appearance, lifecycle, file integrity, local conversation workspace, safe storage management, compact settings, TrollStore readiness policy and adaptive particles have also been staged. Historic duplicate Game Agent patches are held for supersedence adjudication. **The integrated candidate is not a released or verified IPA until macOS CI, XCTest, old-data migration, backward communication and release artifact gates complete.**


The branch is based on the complete 26.11 Build 57 release tree and carries
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

The release additionally carries Tactical Solo V1, the compact
local Tool Center expansion, LAN Turbo hardening, centralized adaptive/God-mode
motion quality, and three deterministic 2D games (弧光炮战、光轨突围、磁轨冰球) that share their
rule state across local Bot and nearby encrypted multiplayer. These additions do
not change Protocol 4, VLGM1 v1 or SQLite Schema V8.

Build 58 expands the real-time game collection with Prism Rift 3D, Afterglow Convoy,
Ash Harbor, Rainline Last Train, Signal Dive and Blackout District. Render quality adapts
to device and Reduce Motion settings, while authenticated God Mode can retain the existing
high-refresh/full-effects override. Imported Kenney assets are CC0 and ShaderKit components
retain their MIT notice; every game remains fully offline and preserves a procedural fallback.
