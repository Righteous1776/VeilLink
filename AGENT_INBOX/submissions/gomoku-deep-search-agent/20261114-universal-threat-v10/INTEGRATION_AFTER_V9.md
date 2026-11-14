# Minimal future hook (owner/local artifact has full notes)

ONLY after the Integration Governor resolves draft PR #199. No live lane granted.

In `GomokuBot.chooseMove` after mandatory own-five, opponent-five and R8 and before V9 search, consider opt-in on `forcingDepth >= 3`:

```swift
if forcingDepth >= 3 {
    let now = Date.timeIntervalSinceReferenceDate
    let slice = min(0.12, max(0, deadline - now) * 0.10)
    if slice >= 0.010,
       let proof = GomokuUniversalThreatV10.provenThreeTurnOpener(
            in: state, for: player, roots: candidates,
            deadline: now + slice, nodeCap: 6_000
       ) {
        nodes += proof.workUnitsChecked  // mixed checks, not PVS nodes
        return result(index: proof.firstMove, score: winScore-3,
                      nodes: nodes, started: started)
    }
}
```

Do not reveal any internal root/defender square to ECLIPSE while a match is unfinished. A nil proof must preserve existing V9/R4/R6 behavior. This hook is review guidance, not a tested iOS product patch.
