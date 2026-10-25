# R7 PROPOSAL

Supersedes R6 PR #83 with complete 13-file add-only candidate patch. See PATCH.diff and FILES.

- Fixed 390×600 virtual SpriteKit canvas .aspectFit; avoids stretched nodes.
- Cache 16 deterministic chart notes once per seed/district; hot update no chart regeneration.
- Running snapshot older than 280ms blanks notes rather than freezing at wrong position; paused snapshots freeze by design.
- Bounded 240-call frame interval stats (not GPU telemetry).
- 4 four-lane accessible SwiftUI input controls outside ScrollView with 56pt minimum height; 12Hz reactive HUD instead of 20Hz; SpriteKit requests 30Hz.
- Tests can import either Linux SwiftPM VeilMegaEngines or iOS App VeilLink.

Requires R5 #79 types to be integrated before this, and P0 touch/consent #64/#65/#66 arbitration.
Nothing enters main or installed App from this Inbox-only commit.
