# Verification artifacts

Repository baseline: eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0 (2026-11-14 verification).
Other agent: [draft V9 #199](https://github.com/Righteous1776/VeilLink/pull/199). This draft remains unmerged; #193/#196, #186, #187, #203 may also overlap after integration.

Owner V10 ZIP SHA256: 6b2e96dceb15ce7f250f6333d5b6776a6a5a9df529a369612db637c4e13efeb0.
Swift source SHA256: 1753770927ceaad9509acd6b40b45fe255f044547cb865467a216174514e78f8.
Proposed XCTest SHA256: f6af4a442adc4807047d28090dc3d114aed835b9b30de4fd6c732acff3c684c5.
Owner's **real two-file product** patch SHA256: 03f497b74aa0eb1b35c4a487ef0957be00bf727d09c834ca39cf231650412676.
This Github Inbox `PATCH.diff` now contains the complete two-file product patch. Both staged Swift blobs match byte-for-byte the owner-tested local source and XCTest (Git blob SHAs f4cb1714664fc3179a9cb3781558649df65249d2 and c66e5fe8724fa6110c926e2613167b38c967f79d). Reconstructed equivalent patch passed isolated git apply --check/apply and exact source comparison. This does NOT mean it was applied to a real main checkout.

Standalone logs: black open-three 8/8, white 8/8; opponent immediate-winning counterexample rejected 8/8; ordinary single-three rejected 8/8; node and time exhaustion both rejected 8/8; total 48/48.
Independent oracle: 1728 black + 1720 white defense alternatives covered.
Random legal board set: 120 positions, no claims, no win-rate measured.
No actual product compile, source merge, iOS build, IPA or user data transformation.
