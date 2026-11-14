import Foundation

private func require(_ assertion: @autoclosure () -> Bool, _ text: String) {
    precondition(assertion(), text)
}

@main struct EclipsePolicyTestRunner {
    static func main() {
        typealias P = VeilEclipseTracePolicy
        let moves: [P.PlacedMove] = [
            .init(index: 112, stone: 1), .init(index: 113, stone: 2),
            .init(index: 97, stone: 1), .init(index: 98, stone: 2)
        ]
        let hidden = P.replayFrames(moves, matchFinished: false, separateReadOnlyPanel: true)
        require(hidden.isEmpty, "Active matches must never expose replay")
        let hiddenInBoard = P.replayFrames(moves, matchFinished: true, separateReadOnlyPanel: false)
        require(hiddenInBoard.isEmpty, "Live board cannot be a replay canvas")
        let valid = P.replayFrames(moves, matchFinished: true, separateReadOnlyPanel: true)
        require(valid.count == 5 && valid.last?.lastCommittedIndex == 98,
                "Only committed actual moves may appear in replay")
        let trace = P.RawSearchEvent(origin: .measuredEngine, completedDepth: 5,
                                     visitedNodes: 12034, principalVariation: [82, 83, 84],
                                     consideredIndices: [67, 123], explanation: "Private root annotations")
        let publicMetrics = P.liveMetrics(from: trace)
        require(publicMetrics?.completedDepth == 5 && publicMetrics?.visitedNodes == 12034,
                "Live view receives only data with NO coordinate fields")
        let during = P.publicAnalysis(from: trace, matchFinished: false,
                                      separateReadOnlyPanel: true, verifiedReplay: valid)
        require(during.completedDepth == 5 && during.visitedNodes == 12034,
                "Measured totals are safe to show during search")
        require(during.actualMoves.isEmpty && during.explanation == nil && !during.canReplaySpatialData,
                "No coordinates or explanations leak during active play")
        let after = P.publicAnalysis(from: trace, matchFinished: true,
                                     separateReadOnlyPanel: true, verifiedReplay: valid)
        require(after.canReplaySpatialData && after.actualMoves == moves.map(\.index),
                "Completed replay uses only confirmed moves, NOT private PV")
        require(!after.actualMoves.contains(82) && !after.actualMoves.contains(67),
                "Candidate hints and uncommitted PV coordinates must never escape")
        let invalidDup = moves + [.init(index: 112, stone: 1)]
        require(P.replayFrames(invalidDup, matchFinished: true, separateReadOnlyPanel: true).isEmpty,
                "Repeated cells must invalidate replay")
        require(P.replayFrames([.init(index: 0, stone: 2)], matchFinished: true,
                               separateReadOnlyPanel: true).isEmpty,
                "Black must move first")
        require(P.replayFrames([.init(index: 225, stone: 1)], matchFinished: true,
                               separateReadOnlyPanel: true).isEmpty,
                "Indices outside 15x15 must be rejected")
        require(P.replayFrames(moves, matchFinished: true, separateReadOnlyPanel: true,
                               expectedFinalBoard: Array(repeating: 0, count: 225)).isEmpty,
                "Replay must match the actual final board")
        let example = P.RawSearchEvent(origin: .exampleOnly, completedDepth: 9,
                                      visitedNodes: 9999, principalVariation: [99],
                                      consideredIndices: [123], explanation: "Fake")
        let examplePresentation = P.publicAnalysis(from: example, matchFinished: true,
                                                    separateReadOnlyPanel: true, verifiedReplay: valid)
        require(examplePresentation.completedDepth == nil && examplePresentation.actualMoves.isEmpty,
                "Historical examples must not be misrepresented as engine telemetry")
        // Four-in-a-row with alternating white moves; the fifth black completes a win.
        let winning: [P.PlacedMove] = [
            .init(index: 0, stone: 1), .init(index: 15, stone: 2),
            .init(index: 1, stone: 1), .init(index: 16, stone: 2),
            .init(index: 2, stone: 1), .init(index: 17, stone: 2),
            .init(index: 3, stone: 1), .init(index: 18, stone: 2),
            .init(index: 4, stone: 1)
        ]
        require(P.replayFrames(winning, matchFinished: true, separateReadOnlyPanel: true).count == 10,
                "Completed winning match is valid")
        require(P.replayFrames(winning + [.init(index: 19, stone: 2)], matchFinished: true,
                               separateReadOnlyPanel: true).isEmpty,
                "Move after a win must not be shown")
        let recorded = P.RawSearchEvent(origin: .recordedEngine, completedDepth: 7,
                                        visitedNodes: 99999, principalVariation: [67],
                                        consideredIndices: [123], explanation: "未来推荐：83")
        require(P.liveMetrics(from: recorded) == nil,
                "Recorded search must never masquerade as live telemetry")
        let post = P.publicAnalysis(from: recorded, matchFinished: true,
                                    separateReadOnlyPanel: true, verifiedReplay: valid)
        require(post.completedDepth == nil && post.visitedNodes == nil && post.explanation == nil,
                "Recorded source and private strategic prose must remain hidden")
        require(after.explanation == nil,
                "Even measured raw text cannot leak speculative moves after match")
        print("PASS: 18 policy assertions covering hint isolation and validated replay")
    }
}
