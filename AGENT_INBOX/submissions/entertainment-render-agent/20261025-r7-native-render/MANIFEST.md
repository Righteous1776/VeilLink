# R7 Complete Source Intake — entertainment-render-agent

agent_id: entertainment-render-agent
task_id: 20261025-r7-native-render
base_main_sha: 501ef814a0a9bea41419fe2d9f48315371b30320
status: DROPPED (INBOX_ONLY; integration BLOCKED by Wave 0)
toolcenter_group: 娱乐
depends_on: Wave 0 (#64–#66), R4 E191 engine, R5 #79; R6 #83 is superseded
scope: 13 complete R7 candidate product/test files under FILES/, plus 2 original R7 smoke tests retained from first drop
advisory_product_patch: PATCH.diff (7928f29e249d17350a71318ff2e4fe8d276638e88584a680f66e8a79452d0396)
optional_governor_combined_candidate: WAVE1_COMBINED_CANDIDATE.diff (0f34ce788745b16f797f63a4224590c90dc1188506af308304e926bafd4f9014) — 20 files, NOT APPLIED
checks: git apply --check --whitespace=error-all PASS for both patches; sources byte-equal fixtures
linux: swift test -j 2 -> 128 XCTest / 0 failed; swift build -c release -> PASS
ios_sdk: PENDING (macOS/Xcode unavailable)
iphone7_15_8_3: PENDING (physical device unavailable)
release_main_ipa: NONE; SQLite/Wire/Keychain/A9/A10 untouched
asset_grant: none; binary assets: none
