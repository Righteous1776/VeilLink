import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct MaleCNSLearnedReadoutResult: Equatable, Sendable {
    let label: String
    let confidence: Float
    let probabilities: [Float]
}

struct MaleCNSLearnedReadoutModel: Decodable, Sendable {
    struct Normalization: Decodable, Sendable {
        let logTotalDivisor: Float
        let logFinalDivisor: Float
        let stepsDivisor: Float

        enum CodingKeys: String, CodingKey {
            case logTotalDivisor = "log_total_divisor"
            case logFinalDivisor = "log_final_divisor"
            case stepsDivisor = "steps_divisor"
        }
    }

    struct Layer: Decodable, Sendable {
        let activation: String
        let weight: [[Float]]
        let bias: [Float]
    }

    let id: String
    let schema: Int
    let graphTier: String
    let graphSHA256: String
    let graphNeurons: Int
    let graphEdges: Int
    let classes: [String]
    let readoutGroups: [String]
    let readoutGroupSizes: [Int]
    let featureTail: [String]
    let normalization: Normalization
    let layers: [Layer]

    enum CodingKeys: String, CodingKey {
        case id, schema, classes, normalization, layers
        case graphTier = "graph_tier"
        case graphSHA256 = "graph_sha256"
        case graphNeurons = "graph_neurons"
        case graphEdges = "graph_edges"
        case readoutGroups = "readout_groups"
        case readoutGroupSizes = "readout_group_sizes"
        case featureTail = "feature_tail"
    }

    static func loadBundled(for tier: MaleCNSGraphTier, bundle: Bundle = .main) throws -> MaleCNSLearnedReadoutModel {
        let name: String
        switch tier {
        case .lite: name = "MaleCNSReadoutLiteV1"
        case .core: name = "MaleCNSReadoutCoreV1"
        case .reference: throw VFLY1Error.incompatibleTier
        }
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw VFLY1Error.invalidMetadata
        }
        let model = try JSONDecoder().decode(MaleCNSLearnedReadoutModel.self, from: Data(contentsOf: url))
        try model.validateShape()
        return model
    }

    func validate(profile: MaleCNSGraphRuntimeProfile) throws {
        guard graphTier == profile.tier.rawValue,
              graphNeurons == profile.neuronCount,
              graphEdges == profile.edgeCount else {
            throw VFLY1Error.incompatibleTier
        }
        try validateShape()
    }

    func infer(_ episode: MaleCNSNativeEpisodeReadoutResult) throws -> MaleCNSLearnedReadoutResult {
        guard episode.readout.names.count == episode.readout.spikeCounts.count else {
            throw MaleCNSNativeKernelError.invalidInput
        }
        let table = Dictionary(uniqueKeysWithValues: zip(episode.readout.names, episode.readout.spikeCounts))
        var features: [Float] = []
        features.reserveCapacity(readoutGroups.count + 3)
        for (index, name) in readoutGroups.enumerated() {
            guard let count = table[name] else { throw MaleCNSNativeKernelError.invalidInput }
            let divisor = max(1, readoutGroupSizes[index])
            features.append(Float(count) / Float(divisor))
        }
        features.append(Float(log(1.0 + Double(episode.summary.totalSpikeCount))) / normalization.logTotalDivisor)
        features.append(Float(log(1.0 + Double(episode.summary.finalFiredCount))) / normalization.logFinalDivisor)
        features.append(Float(episode.summary.executedSteps) / normalization.stepsDivisor)

        var vector = features
        for layer in layers {
            vector = try dense(vector, layer: layer)
        }
        guard vector.count == classes.count, let bestIndex = vector.indices.max(by: { vector[$0] < vector[$1] }) else {
            throw MaleCNSNativeKernelError.invalidInput
        }
        let probabilities = softmax(vector)
        return MaleCNSLearnedReadoutResult(
            label: classes[bestIndex],
            confidence: probabilities[bestIndex],
            probabilities: probabilities
        )
    }

    private func validateShape() throws {
        guard schema == 1,
              !classes.isEmpty,
              readoutGroups.count == readoutGroupSizes.count,
              featureTail == ["log_total_spikes", "log_final_fired", "steps_norm"],
              layers.count == 2,
              layers[0].activation == "tanh",
              layers[1].activation == "linear" else {
            throw VFLY1Error.invalidMetadata
        }
        let input = readoutGroups.count + 3
        guard layers[0].weight.allSatisfy({ $0.count == input }),
              layers[0].weight.count == layers[0].bias.count,
              layers[1].weight.allSatisfy({ $0.count == layers[0].bias.count }),
              layers[1].weight.count == layers[1].bias.count,
              layers[1].bias.count == classes.count else {
            throw VFLY1Error.invalidMetadata
        }
    }

    private func dense(_ input: [Float], layer: Layer) throws -> [Float] {
        guard layer.weight.count == layer.bias.count else { throw VFLY1Error.invalidMetadata }
        var output = [Float](repeating: 0, count: layer.bias.count)
        for row in layer.weight.indices {
            guard layer.weight[row].count == input.count else { throw VFLY1Error.invalidMetadata }
            var value = layer.bias[row]
            for column in input.indices { value += layer.weight[row][column] * input[column] }
            switch layer.activation {
            case "tanh": output[row] = Float(tanh(Double(value)))
            case "linear": output[row] = value
            default: throw VFLY1Error.invalidMetadata
            }
        }
        return output
    }

    private func softmax(_ logits: [Float]) -> [Float] {
        guard let maximum = logits.max() else { return [] }
        let exps = logits.map { Float(exp(Double($0 - maximum))) }
        let sum = max(Float.leastNonzeroMagnitude, exps.reduce(0, +))
        return exps.map { $0 / sum }
    }
}
