# V29 application / validation log

Base main2c5b516; intake364601d; ordered plan V29_BATCH_MANIFEST.md.
Owner confirmed experimental Chinese-unvalidated LingCore inclusion while
retaining all compile/test/IPA gates. No source branch was rewritten.

Applied ancestry: current Veilopoly afa5607 (82c7440), V5/manual1f653269
(1cbe4d2), verified board c40613d (df1f585), LingCore cdd9fae (0dd9ac0).
Conflict reconciliation: retain BOTH checkpoint histories; latest V4 credit
stress preserved in finiteVersion4, V5 versioned risk logic added; keep current
UI and dynamic versioned supply display. #178 canonical board API; #179 is an
alternative of the same feature, not independently applied twice. New Inbox165
product/test hunks applied;166 already absorbed in board ancestry. Old Inbox
dispositions remain in V28 ledger; protected56/60 not silently promoted.

First combined Linux test368 cases/10 assertions failed. Corrected: baseline
stored trade guard rejects nonpurchasable tax cells; frozen V4 test fixtures
call makeV4, unchanged monetary expectations; manual test selects exactly40
indexed appendix entries (other five board-* overview articles are retained),
plus exact set00..39. No assertion removed. Final Linux368/368 PASS208.335s.
12 paired seeds at2500 actions: legacy7 natural finishes vs city3;100 V5 seeds
at1200 actions all capped, no false completion/performance/bank-run claims.

Pipeline: retain existing Core resource exclusions/default policy; explicit
--experimental-vertex requires one pinned GGUF, linked/embedded arm64 iOS15
llama and actual app–IPA hash parity. Other forbidden heavy AI assets and A10
shadow hashes unchanged. Include the new Markdown manual in parity checks.
Portable verifier tests5+7 PASS; model source29,203,168 bytes/pinned SHA PASS.
Normal project remains isolated; CI/release generate the separately verified
Vertex build plan. Version29.0/build66 and active validator pins moved together.
Existing80MiB IPA/120MiB app caps remain, not raised to hide payload regressions.

Apple exact-head CI and actual combined artifact validation PENDING. No merge,
release, physical-device verification or installed-phone result claimed here.
Promotion only after green required checks, normal merge and immutable release.

Nine guarded live-session/ACK/lifecycle tests are attached to the actual iOS
test host in project.yml; macOS/Linux package success alone does not run them.

First Apple run42400461288 failed macOS package compilation: Foundation-only
CGRect lacked Darwin overlay initializers/accessors in PanelWorkspace. Replaced
it with a pure Swift value frame and explicit CGFloat conversion at UI boundary;
no geometry/rule change. Move package test before costly native preparation.
Separate validation/v29-device-candidate lane restores exact-digest device llama
from successful native source run42397878336, rebuilds current V29 app and
verifies its bytes. That fast artifact remains PENDING primary complete gates,
not a published release. Original CI and source branches are not overwritten.
