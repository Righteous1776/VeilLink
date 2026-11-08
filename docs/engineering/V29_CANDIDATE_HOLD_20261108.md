# V29 candidate repair — publication HOLD

Task: VLP-P5-CHAT-PARITY-001. Owner explicitly paused formal V29 on
2026-11-08 after testing a candidate. This supersedes the earlier release
authorization. Do not merge main, create a release or dispatch publication.

Verified main: 2c5b5161027edff097b27fe3323d30f6ca3e430e.
Previous tested candidate: 7ecdccedc7833a073217c5a142bb1c19d9cbf2dc.
Full Apple CI42403714966 succeeded, but does NOT satisfy Owner acceptance:
chat invitation access and live/solo parity were not covered by that suite.
PR181 remains draft/unmerged. No formal v29.0-b66 Release exists.
Auxiliary promotion branch572bdb7 disables its publication job (if:false).

## Confirmed call-chain defects

- ChatView's invitation menu and MiniGameHubView only enumerated MiniGameKind.
  Veilopoly was absent. Its bridge UI existed only in the independent Games tab.
- LiveRoom created GameFactory classic states and validated classic paytables;
  solo created VeilopolyCityLongEconomy V5. Both used the same GameView, but
  balances, cards, property prices and financial behavior were different.
- An explicit invite with an unready secure session requested recovery and
  discarded the intent, requiring another tap. Busy rooms returned silently.
- Multiple mounted entry points must not race for the room's full-screen cover.

## Applied source repairs (candidate only)

- Chat invitation menu adds Veilopoly directly; chat's game hub adds a
  current-conversation-scoped multiplayer panel. A transient status/accept/resume
  card is outside the message scroller; no SQLite/chat message schema change.
- A presentation-context ID selects exactly one chat/hub/hall cover for the
  SAME room model. Background Games tabs cannot also present a chat's game.
  Cross-conversation actions cannot accept another peer's invitation by mistake.
- One explicit invite is retained for the existing120s lifetime while secure
  recovery completes. Recovery is requested once, never reset on a game timer.
  Actual unsupported control capability remains rejected with a visible error;
  no text-channel bypass or weakened E2EE checks. Sent status follows transport
  acceptance, not the button tap; transport acceptance is not delivery proof.
- New room metadata explicitly selects V5 and uses the same V5 factory as solo
  (two human/two AI seats). Snapshot validation binds cards, paytables, financial
  version/terms, market algorithm and the fixed2,100,000 currency pool.
- New-profile invitations use APPLICATION packet version2 so legacy version1
  apps reject rather than silently open a classic room. Existing encrypted
  control-event codec, fragments/topic, BLE2048-byte cap and Wire v4 unchanged.
- Absent rulesVersion means the existing classic room. Old room indexes/saves
  are not rewritten/repriced; UI labels them classic and explains a fresh V5
  invitation requires explicitly leaving. No save deletion/migration.
- App foreground/background propagates to the room regardless of the current
  tab; chat reception does not require constructing the game lobby first.

## Verification and scope

Initial directed package run21/21 PASS (current-profile7 + existing live14).
Initial full Linux Swift6.2.1 package375/375 PASS111.366s. A further longest
identity/fragment-budget test and host bridge tests were added afterward;
second full package376/376 PASS91.498s; final directed current/live room suite
24/24 PASS0.290s includes guest financial orders and encoded V5 resume.
Final complete378-case run remains PENDING until separately recorded. Host tests exercise
real bridge + fake authenticated channel, not physical transport.

Portable resource verifier5/5 PASS. The model verifier initially failed fixture
setup because the local overlay filled; removed only96MiB of reproducible .build
cache from the prior clean-baseline test checkout (source/logs retained), then
model verifier7/7 PASS. No product resource/model/native binary was changed.

Apple SDK typecheck/host XCTest, rendered chat navigation, keyboard/landscape
cover behavior and real two-phone invitation/acceptance for this repair are
NOT_RUN until separate evidence. No claim this candidate is owner-accepted.
Prior green tests do not validate the new source. Historical frozen manual/PDF
artifacts remain dated source material; current room rules label is authoritative.

All product edits are isolated on integration/v29-veilopoly-candidate-fix-20261108.
No main/source-branch overwrite, force push, transport/security/identity/SQLite/
A9/A10/A13/version/signing changes. Current VeilLink governance V1.1 is authoritative;
new skill's unavailable seal/readset/07/session/exchange gates are PARTIAL,
not invented PASS and not installed silently.

NEXT_ONE_TASK: exact-head Apple candidate-only compile/XCTest and an actual
chat-to-chat invitation acceptance check. Publication remains OWNER HOLD even
if CI turns green. Resume formal publication only on a new Owner instruction.
