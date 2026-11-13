import Foundation

/// Cross-agent R5 + V9 + ECLIPSE R10 CPU envelope.
/// Mandatory Gomoku win/block/R4/R8 checks remain outside this optional budget.
/// Timings are *ceilings*, never measured Elo or guaranteed skill gains.
enum VeilEclipseComputeContractR10 {
    struct Envelope: Equatable, Sendable {
        let totalMilliseconds: Int
        let v9ProofMilliseconds: Int
        let r5SearchMilliseconds: Int
        let r10ShadowMilliseconds: Int
        let absoluteDeadlineMilliseconds: UInt64

        /// Given caller-supplied monotonic `nowMilliseconds`.
        /// A stale/cancelled turn must be separately rejected by its session ticket.
        func remaining(at nowMilliseconds: UInt64) -> Int {
            guard nowMilliseconds < absoluteDeadlineMilliseconds else { return 0 }
            return Int(min(UInt64(Int.max), absoluteDeadlineMilliseconds - nowMilliseconds))
        }
    }

    /// `masterMilliseconds` is the selected FULL or ECONOMY Master budget
    /// already returned by GomokuBotBudget. This method cannot auto-detect
    /// a device or override the Owner's search-mode choice.
    static func allocate(masterMilliseconds: Int,
                         multiplier: Int,
                         nowMilliseconds: UInt64) -> Envelope? {
        guard masterMilliseconds > 0, [1, 2, 4, 6].contains(multiplier),
              masterMilliseconds <= 20_000 else { return nil }
        let total = masterMilliseconds * multiplier
        let proof = total / 5                  // 20% optional V9 proof
        let shadow = total * 3 / 20             // 15% R10 adversarial planning
        let native = total - proof - shadow     // 65% R5 native PVS
        let duration = UInt64(total)
        guard nowMilliseconds <= UInt64.max - duration else { return nil }
        return Envelope(totalMilliseconds: total,
                        v9ProofMilliseconds: proof,
                        r5SearchMilliseconds: native,
                        r10ShadowMilliseconds: shadow,
                        absoluteDeadlineMilliseconds: nowMilliseconds + duration)
    }
}
