import Foundation

enum MaleCNSStimulus: Equatable, Sendable {
    case looming(side: MaleCNSSide, strength: Float)
    case chaseTarget(side: MaleCNSSide, strength: Float)
    case smallApproach(side: MaleCNSSide, strength: Float)
    case silence
}

enum MaleCNSSide: String, Sendable { case left = "L", right = "R" }

/// Maps compact task observations to named biological feature-detector groups. It never mutates
/// game state and never knows SwiftUI. VFLY group names make the encoder stable across node reindexing.
struct MaleCNSStimulusEncoder: Sendable {
    let artifact: VFLY1Artifact

    func drive(for stimulus: MaleCNSStimulus) -> [Float] {
        var drive = [Float](repeating: 0, count: artifact.graph.neuronCount)
        switch stimulus {
        case .silence: return drive
        case .looming(let side, let strength):
            inject(group: "sensory.LC4.\(side.rawValue)", strength: strength, into: &drive)
            inject(group: "sensory.LPLC2.\(side.rawValue)", strength: strength, into: &drive)
        case .chaseTarget(let side, let strength):
            inject(group: "sensory.LC10a.\(side.rawValue)", strength: strength, into: &drive)
        case .smallApproach(let side, let strength):
            inject(group: "sensory.LPLC1.\(side.rawValue)", strength: strength, into: &drive)
        }
        return drive
    }

    /// R7 fixed game encoder input. The channel order is part of the trained model contract.
    /// It maps compact game features into eight named biological sensory groups while keeping
    /// the MaleCNS connectivity frozen.
    func drive(gameChannels: [Float]) throws -> [Float] {
        let names = [
            "sensory.LC4.L", "sensory.LC4.R",
            "sensory.LPLC2.L", "sensory.LPLC2.R",
            "sensory.LPLC1.L", "sensory.LPLC1.R",
            "sensory.LC10a.L", "sensory.LC10a.R"
        ]
        guard gameChannels.count == names.count,
              gameChannels.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1.55 }) else {
            throw MaleCNSNativeKernelError.invalidInput
        }
        var drive = [Float](repeating: 0, count: artifact.graph.neuronCount)
        for (name, strength) in zip(names, gameChannels) {
            inject(group: name, strength: strength, into: &drive)
        }
        return drive
    }

    private func inject(group name: String, strength: Float, into drive: inout [Float]) {
        guard strength != 0, let group = artifact.group(named: name) else { return }
        for neuron in group.neuronIndices { drive[Int(neuron)] += strength }
    }
}
