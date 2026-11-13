# Native replacement regression plan

Completed locally (Linux Swift 6.2.1): source compiled with strict Swift 6, four tactical cases, board invalid input guards. 212/212 R2 tactical fork cases safe; all 848 rotations safe. Script and source in OWNER-DELIVERED ZIP, deliberately not uploaded into public GitHub due to user game-history privacy and Inbox archive restrictions.

NOT COMPLETED: iOS SDK/SwiftUI integration; XCTest; UI telemetry; VCT all-defender proof; real offline AI-vs-AI equal-budget chess play; win-rate; battery/thermal.

Requirements for Integration Governor:
- check patch source sha256 5ef02d1128d584046475b014a4f47589377dd19123765d8241b164a19fec1b39;
- validate standalone search choices and real authoritative GomokuBot R4/R8 postconditions;
- disallow VCF candidate bypass (9 counterexamples found in initial prototype);
- apply limited time budget, user adjustable strength, no fake search progress;
- verify JS parity for VCF and opening shape and transposition table poisoning;
- no data loss or old model/saved match behavior regression;
- only remove old engine after green real Apple CI.
