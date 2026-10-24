# R4 Validation and Test Protocol

## Exact patch application gate
- Fresh clone pinned at main `8048b5c52b87eeb5d3622582da5728a8c2d64dda`.
- `git apply --check PATCH.diff && git apply PATCH.diff`
- `git apply --check PATCH_STAGE2.diff && git apply PATCH_STAGE2.diff`
- `git apply --check PATCH_STAGE3.diff && git apply PATCH_STAGE3.diff`
- `git apply --check PATCH_STAGE4.diff && git apply PATCH_STAGE4.diff`
- `git diff --check`, inspect 8 proposed product/test files, ensure no build/version/release drift.

## Unit and code-path verification
1. ACK JSON legacy/new/malformed optional compatibility; schema versions and bits 0..7 accepted, unknown bits rejected.
2. Control event envelope kind10 and optional `receiptRequested` cross-version JSON compatibility. Receipt envelope kind11, AEAD domain `control-receipt-v1`, fresh replay sequence, event UUID binding.
3. DB v8→v9→v10 repeated migration, schema foreign keys, legacy user text/files/backup preserve; migration rollback after injected SQL error.
4. One shared ciphertext and two target rows; authenticated ACK A leaves B pending; identical re-enqueue **does not resurrect A**; final ACK deletes shared ciphertext; mismatched UUID body rejected.
5. New SQLite quota guard under the actual atomic INSERT transaction: 512 entries admitted, 513th rejected with rollback, no orphan target rows, no untrusted peer target rows.
6. Identity deletion removes all new outbox rows; trust revocation/different-key receipts cannot acknowledge.
7. Session reconnect, chat ACK negotiation, BLE queue temporarilyUnavailable vs accepted (only accepted increments retries), receipt packet loss, duplicated events, retry backoff, 7-day expiry.
8. Cross-application matrix: legacy Wire4, R2 event-only control client, R4 receipt-capable, offline BLE and LAN and relay; R2 must never see kind11; fresh-session capability required for control send.

## Execution evidence obtained (not product CI)
- Exact four-stage unified diff context/count/roundtrip: **PASS**, 23 file sections, 55 hunks.
- Swift 6.2.1 standalone control event codec: **PASS**, optional receipt flag old/new JSON roundtrip, validation.
- Python sqlite3 in-memory v10 fixture: **PASS**, repeat migrations, A/B independent ACK, no ACK resurrection, 512 quota/rollback, FK enforcement, old message preservation and integrity.
- Agent Inbox Gate on GitHub validates only inbox boundaries and manifests, not Swift compilation.

## Still REQUIRED for promotion
Native macOS XcodeGen / iOS simulator compile + all XCTest tests; actual iPhone 7 iOS15 and modern iPhone BLE/LAN intermittent-loss runs; old/new downgrade matrix; backup/keychain recovery; signed package verification; Governor conflict/arbitration with PR #53; dedicated integration branch, CI green. No IPA release on this PR.
