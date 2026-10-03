# CURRENT CHECKPOINT

VeilLink **26.11 (Build 57)** is the current cumulative release checkpoint. Build 57 adds
native real-time arcade, hardware-backed Live Tools, BLE/LAN transport hardening, PTT/chat
repairs, and explicit render/performance budgets while preserving the complete 26.10 Build 56
release line.

The branch is based on the complete 26.10 Build 56 release tree and carries
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
