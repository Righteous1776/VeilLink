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

    private func inject(group name: String, strength: Float, into drive: inout [Float]) {
        guard strength != 0, let group = artifact.group(named: name) else { return }
        for neuron in group.neuronIndices { drive[Int(neuron)] += strength }
    }
}
