# V28 integration window — 2026-11-07

Task: `VEILLINK-V28-INTEGRATION-20261107`.
Authority: Owner explicitly requested unified Veilopoly + Inbox integration, merge, V28 release and IPA construction. This supersedes the previous no-version-output restriction; it does not waive compile/test/security gates.

## Frozen sources

- Main: `ccafebab147e069fbabfff579dbf323b0d54f191` (27.2/build64).
- Veilopoly: `74203572281b9487356195fbd7cc1f21adb853d1`.
- Dedicated branch: `integration/v28-inbox-veilopoly-20261107`.
- Release target: **28.0 / build65**. No downgrade, force push, source-tree reset or unrelated deletion.
- Inbox cutoff: open PR heads read on 2026-11-07 after the Owner's release instruction. Revision heads and dispositions will be retained in the final intake ledger; later updates require another review.

## Ordered intake decisions before product mutation

| Candidates | Treatment |
| --- | --- |
| Veilopoly development branch | Carry existing branch intact: actual game-hall/fullscreen hosting, engine/AI, finance/stock, autosave, generated/runtime art, editorial and quiet news. |
| #137 | Apply reviewed main-thread logging/telemetry and reconnect damping first. Preserve lock-protected UI snapshots. |
| #138 | Preserve startup signposts. Image policy is superseded by #156, not its hard BLE cap. |
| #139 | Apply bottom anchor, invitation gesture and insertion-order tie handling, reconcile other chat changes. No schema migration. |
| #128–134, #136 | Review current-base side selection, secure import staging, recovery, legal IME, temporary cleanup, unique exports and async-test wait budget; apply nonduplicate fixes with overlap reconciliation. |
| #140 + #147 | Reconcile safe draft import with bounded provider copy and staging leases. No generic encrypted binary content kind is authorized. |
| #144/#146/#149/#150 | Superseded by reconciled #151; combine with #137 without discarding reconnect damping. These are logical scheduling lanes, not hardware/headset thread allocation claims. |
| #145 | Review deferred full integrity audit; preserve synchronous key/migration verification and explicit unchecked health. |
| #152–155 | Superseded by #156 nonblocking image preparation. Only existing 3MB protocol cap is a hard admission limit. |
| #157 | Review brightness snapshot deduplication against the current diagnostics changes. |
| #158 | Superseded by #159 durable local board recovery; reconcile chosen-side and new-game semantics. |
| #160 | Review original native opponent UI and policy. MP4/GIF binaries are not in the PR; never claim that unavailable footage was shipped. Keep a truthful native fallback unless the actual authorized asset is found. |
| #141 / #142–143 | Original Owner directive requires explicit semantic clarification for ⑩/⑥. Asked Owner again; hold these source changes until answered. |
| #135/#148 | Integration/triage guidance, not additional product implementations. |
| Older Inbox / stale integration PRs | Compare current source and exact reverse-apply evidence. Preserve already-integrated functionality; do not reapply older snapshots, schema/protocol migrations or resurrect quarantined branches. Reference-only catalogs are not delivered features. |

## Safety and validation

No changes to Relay 60s/X25519/six-digit semantics, Wire v4 framing, SQLite schema, identity keys, M5 shadow/production-cutover or A9/A10 authority. Owner authorizes version/release and controlled integration, not broad security-policy changes. No Issue #6 write and no unrelated PR closure.

Current repository has Inbox V1.1, not the newer skill template's `07_LEARNING_GATE.md`, study gate, constitutional seal, mandatory-read set or Exchange/Session installation. These absences were checked in Git and are not fabricated passes or reasons to install another governance system. Applicable current repository originals and Issue #6 were read. The supplemental skill gate is PARTIAL/UNAVAILABLE; Owner's explicit instruction and current repo authority govern this window.

Required evidence: patch applicability/reconciliation, protected-surface diff review, static preflight, package tests, XcodeGen, full Apple simulator build/XCTest, unsigned iPhoneOS Release build, verified offline assets in the actual app/IPA, carrier size/hash/identity verification and remote readback. Linux or syntax parsing is not an Apple build or device pass. Physical-device RF/power/graphics evidence remains separate.

Existing PR CI packages an unsigned candidate; main project identity changes trigger the Core release workflow. These paths are now authorized only after the integration is ready for their gates. Do not bypass a red check or use an administrative merge to conceal failed build/tests. Existing signing policy produces an **unsigned** IPA; no signing credentials are invented.
