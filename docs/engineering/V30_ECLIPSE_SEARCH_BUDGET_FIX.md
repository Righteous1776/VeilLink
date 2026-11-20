# V30 ECLIPSE R14–R17 native budget inheritance fix

Confirmed defect on V30 candidate c5fa3a5f: in GomokuBot.chooseMove, after the
mandatory win/block/two-ply safety gates, the native unified PVS budget was
constructed without the selected searchStrength/unlimitedThinking options.
Because the memberwise initializer defaults to 5/false, the real user controls
were silently reset even though GameLobbyView and LocalAIGameController were wired.

Resolved: GomokuBotBudget.nativeContinuationBudget(from:remainingMilliseconds:)
copies the selected node/depth strength and no-time-limit flag and preserves
existing candidate/radius/root limits. The native bridge continues to enforce
finite nodes and depth; an unlimited wall-clock does not imply unbounded work.

Added XCTest for 10/untimed and 1/timed through the exact handoff API,
plus fail-closed source preflight regression marker.

No Action or IPA triggered. This staging branch has no PR and requires review
before inclusion in the single V30 release candidate.
