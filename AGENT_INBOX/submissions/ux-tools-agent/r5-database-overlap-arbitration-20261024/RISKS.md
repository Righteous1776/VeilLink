# RISKS & overlap arbitration

**Protected surfaces**: DatabaseStore.swift (schema v9/v10), SessionCoordinator.swift (signed Hello and encrypted control), WireCodec.swift, identity Ed25519, reliability/replay, iOS distribution. These are protected and require Integration Governor arbitration. This Lane made **no** protected product edits.

**PR #53 vs #56 design overlap**: PR #53 proposes a competing v9 layout in COMPATIBILITY_PLAN.md, NOT an implemented migration. PR #56 R1-R3 supplies concrete v9/v10 schema. Do not merge two CREATE TABLE peer_capabilities definitions or write two independent v9 markers. Governor should record PR #53's proposed persistence fields as deferred, retain its UI/runtime contributions separately.

**Independent overlap**: PR #53 SettingsView intersects PR #50 storage management. PR #56 DatabaseStore/SessionCoordinator/WireCodec overlap any currently open migration/transport proposals; Governor must rescan the full queue before implementation.

**Security**: A signed optional Hello capability is not a replacement for legacy identity verification. Cache is advisory, trust/key fingerprint current. A stripped optional extension downgrades features and can cause availability loss, not new rights. Reject any patch that authorizes kinds 10/11 from stale cache or TrollStore markers. R2 unknown bit7 is a mandatory cross-version rejection hazard.

**Data**: v9/v10 must be append-only schema evolution. A failed migration must leave transaction state recoverable. Plain DB downgrade to old code is not guaranteed merely because old tables survive; test backup/restore and optionally export a compatible format before shipping.

**Performance**: larger Hello payload can exceed real-world iPhone 7 BLE MTU; retry loop can drain battery or cause flood. Validate with real devices and weak links.

**Validation**: Linux Swift/iOS SDK and Xcode are unavailable in this task runtime. Static patch replay and synthetic sqlite3 structure PASS, but neither is Xcode compile nor XCTest nor real-backup migration. Claim no native success.

**Rollback**: Leave Build 59 recovery anchor; do not overwrite main. If any gate fails, abort independent integration branch, restore only from verified v8 backup, preserve original user data, and never publish IPA. A release requiring rollback must follow owner/Governor release policy.
