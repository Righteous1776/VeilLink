import Foundation

/// Optional bridge: routes R11's exhaustive short-tactic audit into R10.
/// Mandatory R4/R8/V9 source gates must run BEFORE this bridge. When an audit
/// is incomplete or not yet promotion-authorized, it cannot veto any move.
/// ECLIPSE R9 live UI may only consume vetted coordinate-free counters; never
/// expose private variations, tactical roots or counterpart replies.
enum VeilEclipseR11DecisionBridge {
    enum Mode: Sendable {
        case shadow
        case enforceAfterGovernorApproval
    }

    struct Outcome: Sendable {
        let decision: VeilEclipseStrategicPlannerR10.Decision?
        let auditComplete: Bool
        let rejectedUnsafeRoots: Int
        let examinedWindows: Int
    }

    static func choose(
        position: VeilEclipseStrategicPlannerR10.Position,
        vettedRoots: [Int],
        recentOpponentMoves: [Int] = [],
        predictedReplyIndices: [Int] = [],
        rootPreferences: [Int: Int] = [:],
        limits: VeilEclipseStrategicPlannerR10.Limits,
        mode: Mode = .shadow
    ) -> Outcome {
        // One source of time truth; do not multiply R10's allocation on top
        // of the shared V9/R5/R10 envelope.
        let started = Date.timeIntervalSinceReferenceDate
        let budgetMilliseconds = max(1, limits.maxMilliseconds)
        let absoluteDeadline = started + Double(budgetMilliseconds) / 1_000

        // Shadow path is decision-identical to incumbent R10. Do not run
        // speculative R11 work before the selected published move.
        if case .shadow = mode {
            let picked = VeilEclipseStrategicPlannerR10.choose(
                position: position, vettedRoots: vettedRoots,
                opponentRecentMoves: recentOpponentMoves,
                predictedReplyIndices: predictedReplyIndices,
                rootPreferences: rootPreferences, limits: limits
            )
            let remaining = absoluteDeadline - Date.timeIntervalSinceReferenceDate
            let audit = remaining > 0.005 ? VeilEclipseTacticalOracleR11.audit(
                position: position, vettedRoots: vettedRoots,
                deadline: absoluteDeadline
            ) : nil
            return Outcome(decision: picked, auditComplete: audit != nil,
                           rejectedUnsafeRoots: 0,
                           examinedWindows: audit?.examinedWindows ?? 0)
        }

        // Governor-authorized enforcement only: audit takes at most 35% of
        // R10's time slice, never a second independent time allowance.
        let oracleDeadline = min(
            absoluteDeadline,
            started + Double(max(1, budgetMilliseconds * 35 / 100)) / 1_000
        )
        let audit = VeilEclipseTacticalOracleR11.audit(
            position: position, vettedRoots: vettedRoots,
            deadline: oracleDeadline
        )
        let roots = audit?.certifiedWins.isEmpty == false
            ? audit!.certifiedWins
            : (audit?.filteredRoots ?? vettedRoots)
        let remainingMs = max(1, Int((absoluteDeadline - Date.timeIntervalSinceReferenceDate) * 1_000))
        var effective = limits
        effective.maxMilliseconds = min(budgetMilliseconds, remainingMs)
        let picked = VeilEclipseStrategicPlannerR10.choose(
            position: position, vettedRoots: roots,
            opponentRecentMoves: recentOpponentMoves,
            predictedReplyIndices: predictedReplyIndices,
            rootPreferences: rootPreferences,
            limits: effective
        )
        let rejected = audit == nil ? 0 : max(0, Set(vettedRoots).count - roots.count)
        return Outcome(decision: picked, auditComplete: audit != nil,
                       rejectedUnsafeRoots: rejected,
                       examinedWindows: audit?.examinedWindows ?? 0)
    }
}
