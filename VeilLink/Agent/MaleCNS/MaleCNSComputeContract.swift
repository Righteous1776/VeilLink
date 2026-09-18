import Foundation

/// Stable boundary between A9 compute scheduling and the future MaleCNS native runtime.
/// The runtime may consume less than the budget, but must never exceed it without a new plan.
protocol MaleCNSComputeConsumer: AnyObject {
    func applyComputeBudget(_ budget: MaleCNSComputeBudget)
    func trimComputeState()
}

struct MaleCNSExecutionStamp: Equatable, Sendable {
    let graphVersion: String
    let encoderVersion: String
    let readoutVersion: String
    let seed: UInt64
    let budgetTier: MaleCNSComputeTier
    let workerCount: Int
    let neuralStepBudget: Int
}
