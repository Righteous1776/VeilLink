# V28 diagnostic queue test receipt

Task: VEILLINK-V28-INTEGRATION-20261107. Owner requested expedited completion.

After PR #161 passed the full Apple CI and IPA gate, identical production inputs
on main's parallel iOS CI hit the new diagnostic concurrent-logging test's
1-second polling assumption: 70/100 entries were visible at timeout. The release
workflow's own full host tests passed. The failure is retained at run
42347166747; it is not relabeled PASS or silently retried away.

Formal release run 42347166825 was cancelled before publication. This correction
changes only the XCTest helper: use DiagnosticLogStore.exportBundle's existing
serial-queue synchronization, then assert the full count, uniqueness and order.
No production queue implementation, timeout, logging guarantee or app feature is
changed. Export snapshots created by the test are explicitly cleaned up.

The follow-up PR must pass real Apple CI. Owner-authorized expedited publication
may reuse the already verified unsigned IPA from successful candidate run
42345498509 ONLY after verifying release input trees are unchanged, ZIP CRC,
28.0/65 identity, executable/resource hashes, and the manifest SHA-256. Its true
build/run provenance must be published; do not pretend the cancelled release run
completed or that the binary was rebuilt from a later test-only commit.

Candidate evidence: 237 package tests, 865 host tests, UI smoke, iOS Simulator and
iPhoneOS Release, Core carrier and 113 offline resources passed. Final test-fix
and publication results must be read back separately before declaring RELEASED.
