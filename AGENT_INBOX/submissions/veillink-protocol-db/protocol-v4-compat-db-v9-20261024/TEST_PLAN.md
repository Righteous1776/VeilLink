# VeilLink R5 — Hello bootstrap and compatibility test plan

## Stage application (Governor controlled)

Pin exact main SHA `8048b5c52b87eeb5d3622582da5728a8c2d64dda`. Apply and verify sequentially: `PATCH.diff` then `PATCH_STAGE2.diff` then `PATCH_STAGE3.diff` then `PATCH_STAGE4.diff` then `PATCH_STAGE5.diff`. Run `git apply --check` before each, full `git diff --check`, XcodeGen, iOS 15 XCTest. Never skip earlier stages.

## Proposed native XCTest
- `VeilHelloCapabilityTests`: old `LegacyHello` decodes the extended JSON and verifies unchanged old signature; new Hello decodes original old JSON with missing optional fields; valid second identity signature yields recognized bit7; any bit tampering drops optional capabilities; tampered agreement ephemeral cannot reuse extension proof; unknown schema and high bits produce no enhanced capability.
- `VeilPeerCapabilityPolicyTests`: optional ACK with R2 known bits 3 until verified peer bit2; after R5/R4 signed/real ACK bit2, bits 7 permitted; old ACK decoded without extension; malformed optionals cannot break genuine message ACK.
- Existing R1..R4 codec, replay, expiry, duplicate receipt, per-peer outbox tests remain required.
- Test old/new BLE v4 Hello packets at real BLE MTUs, with and without optional fields, despite increased signed-hello size.

## Threat matrix
- Modify unsigned extension schema/bits/signature while preserving valid v4 signature => **legacy handshake may continue, feature capability MUST be nil**.
- Modify v4 ephemeral, identity, display name or nonce => original Hello Ed25519 verification MUST reject packet.
- Replay an extension from an earlier handshake => must fail due to binding to different ephemeral and nonce.
- Strip extension or send unknown future capability schema => valid v4 should remain usable, advanced features disabled.
- New peer may never issue control kinds 10/11 unless signed Hello or authenticated current-session chat ACK proves corresponding feature bits AND trusted peer key is pinned.

## Independently performed local checks
- Five progressive unified diffs generated and re-applied to stage-snapshots; exact context/count and patch roundtrip: PASS.
- Linux Swift 6.2.1 Foundation Codable harness: optional new/old Hello JSON, memberwise optional defaults, unchanged original v4 signedPayload: PASS.
- Python cryptography/Ed25519 separate transcript harness: legitimate v4/extension signature passes, modified bits/session transcript fails: PASS.
- These are focused preflight proofs, **not** the app's native iOS XCTest build.

## Outstanding promotion gates
- Xcode/macOS compilation, all app XCTest, real BLE/LAN/relay and battery/resource trials, iPhone 7 iOS15 old/new mixed versions, full SQLite v8->v10 restore/rollback, authenticated handshake fuzz and signed IPA tests. No native device evidence yet.
