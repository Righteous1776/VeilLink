# R5 PLAYABILITY HARDENING — 2026-10-25

**Verified owner-facing complete package:** `VeilLink_Monogatari_Playability_R5_20261025.zip`
- exact size **5,697,469 bytes**
- SHA-256 `068ba55bfa36672d61960240a684dc4d90ceb7a10868409baf73bc4e6ac6c6f1`
- 115 packaged files; 114 per-file SHA256SUMS entries validated.
- upstream `monogatari-v2.8.0.zip` verified SHA256 `16d221485888b0193312e9989ecafa57cb1913978bf2f09ba554552ba3885806` and **12/12 pristine upstream engine files**.

## Actual R5 fixes in owner's ZIP
1. Load native error bridge **before** the official engine, so boot exceptions aren't invisible.
2. Monogatari init Promise: catch both direct synchronous throw and rejected async result.
3. Independent `localStorage` witness keyed only to VN application metadata; per-origin native UserDefaults expectation warns if the marker disappears. Never reads, rewrites, imports or deletes actual Monogatari saved games. A marker surviving **does not prove actual saved-game durability**.
4. Verify both essential JS glue files exist before game navigation; handle post-commit WebKit navigation failures as well as provisional errors.
5. Keep complete upstream engine unmodified and preserve explicit dual loading modes, no automatic cross-origin migration.

## Executed local tests
- 5 Python R4 regression suites PASS
- 5 Node suites including R5 bridge + 3 init outcomes PASS
- 15 Swift Foundation Range cases PASS; Swift iOS sources **syntax parsed only**
- real vendor ZIP rebuilt into 60 bit-identical game files PASS
- game graph 19 nodes, 3 choices, 4 endings and 36 states PASS
- git apply --check / whitespace=error for complete source-only candidate patch PASS
- Browser was **BLOCKED_BY_ADMINISTRATOR** for localhost, data:, and file: URLs: **no game UI/interaction run**.
- **No macOS iOS15 build, XCTest with Apple SDK, physical iPhone7 gameplay or real save/load after force-quit.**

## Governance and completeness
This Draft PR only stages **text-only partial source + auditable receipt**. Complete modified SwiftUI/WebKit host, full vendor and JS sources and binaries are in exact owner's R5 ZIP, NOT in this PR. Governor must verify/import the ZIP on an isolated integration branch, reconcile P0 #64/#65/#66 touch/signing/data continuity, XcodeGen bundle resource structure, build full Apple iOS15/XCTest, and conduct physical iPhone7 validation. **Do not merge main or dispatch IPA/release.**
