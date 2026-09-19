import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct MaleCNSGameRankResult: Equatable, Sendable {
    let score: Float
    let graphTier: String
    let modelID: String
}

struct MaleCNSGameRankerModel: Decodable, Sendable {
    struct Tensor: Decodable, Sendable {
        let shape: [Int]
        let values: [Float]
    }
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

    let schema: Int
    let id: String
    let graphTier: String
    let graphSHA256: String
    let games: [String]
    let inputFeatures: [String]
    let architecture: String
    let readoutGroups: [String]
    let readoutGroupSizes: [Int]
    let normalization: Normalization
    let deploymentEligible: Bool
    let deploymentNote: String
    let tensors: [String: Tensor]

    enum CodingKeys: String, CodingKey {
        case schema, id, games, architecture, tensors, normalization
        case graphTier = "graph_tier"
        case graphSHA256 = "graph_sha256"
        case inputFeatures = "input_features"
        case readoutGroups = "readout_groups"
        case readoutGroupSizes = "readout_group_sizes"
        case deploymentEligible = "deployment_eligible"
        case deploymentNote = "deployment_note"
    }

    static func loadBundled(
        for tier: MaleCNSGraphTier,
        allowExperimental: Bool = false,
        bundle: Bundle = .main
    ) throws -> MaleCNSGameRankerModel {
        let name: String
        switch tier {
        case .lite: name = "MaleCNSGameRankerLiteV1"
        case .core: name = "MaleCNSGameRankerCoreV1"
        case .reference: throw VFLY1Error.incompatibleTier
        }
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw VFLY1Error.invalidMetadata
        }
        let model = try JSONDecoder().decode(MaleCNSGameRankerModel.self, from: Data(contentsOf: url))
        try model.validateShape()
        guard model.graphTier == tier.rawValue else { throw VFLY1Error.incompatibleTier }
        guard model.deploymentEligible || allowExperimental else { throw VFLY1Error.incompatibleTier }
        return model
    }

    func validate(profile: MaleCNSGraphRuntimeProfile) throws {
        guard graphTier == profile.tier.rawValue else { throw VFLY1Error.incompatibleTier }
        try validateShape()
    }

    func score(
        game: MiniGameKind,
        stimulus: [Float],
        episode: MaleCNSNativeEpisodeReadoutResult
    ) throws -> MaleCNSGameRankResult {
        guard stimulus.count == 8,
              episode.readout.names.count == episode.readout.spikeCounts.count,
              let gameIndex = gameIndex(game) else {
            throw MaleCNSNativeKernelError.invalidInput
        }
        let table = Dictionary(uniqueKeysWithValues: zip(episode.readout.names, episode.readout.spikeCounts))
        var input = stimulus
        input.reserveCapacity(inputFeatures.count)
        for (index, name) in readoutGroups.enumerated() {
            guard let count = table[name], readoutGroupSizes.indices.contains(index) else {
                throw MaleCNSNativeKernelError.invalidInput
            }
            input.append(Float(count) / Float(max(1, readoutGroupSizes[index])))
        }
        input.append(Float(log(1.0 + Double(episode.summary.totalSpikeCount))) / normalization.logTotalDivisor)
        input.append(Float(log(1.0 + Double(episode.summary.finalFiredCount))) / normalization.logFinalDivisor)
        input.append(Float(episode.summary.executedSteps) / normalization.stepsDivisor)
        guard input.count == inputFeatures.count else { throw MaleCNSNativeKernelError.invalidInput }

        let gameWeight = try required("game.weight", shape: [3, 8])
        let embeddingStart = gameIndex * 8
        let embedding = Array(gameWeight.values[embeddingStart..<(embeddingStart + 8)])
        let merged = input + embedding
        var hidden = try linear(merged, weight: "net.0.weight", bias: "net.0.bias")
        hidden = gelu(hidden)
        hidden = try layerNorm(hidden, weight: "net.2.weight", bias: "net.2.bias")
        hidden = try linear(hidden, weight: "net.3.weight", bias: "net.3.bias")
        hidden = gelu(hidden)
        let output = try linear(hidden, weight: "net.5.weight", bias: "net.5.bias")
        guard output.count == 1 else { throw MaleCNSNativeKernelError.invalidInput }
        return MaleCNSGameRankResult(score: output[0], graphTier: graphTier, modelID: id)
    }

    private func validateShape() throws {
        guard schema == 1,
              games == ["gomoku", "xiangqi", "ludo"],
              inputFeatures.count == 8 + readoutGroups.count + 3,
              readoutGroups.count == readoutGroupSizes.count else {
            throw VFLY1Error.invalidMetadata
        }
        _ = try required("game.weight", shape: [3, 8])
        _ = try required("net.0.weight", shape: [48, inputFeatures.count + 8])
        _ = try required("net.0.bias", shape: [48])
        _ = try required("net.2.weight", shape: [48])
        _ = try required("net.2.bias", shape: [48])
        _ = try required("net.3.weight", shape: [24, 48])
        _ = try required("net.3.bias", shape: [24])
        _ = try required("net.5.weight", shape: [1, 24])
        _ = try required("net.5.bias", shape: [1])
    }

    private func gameIndex(_ game: MiniGameKind) -> Int? {
        switch game {
        case .gomoku: return 0
        case .xiangqi: return 1
        case .ludo: return 2
        case .tactical: return nil
        }
    }

    private func required(_ name: String, shape: [Int]) throws -> Tensor {
        guard let tensor = tensors[name], tensor.shape == shape,
              tensor.values.count == shape.reduce(1, *) else {
            throw VFLY1Error.invalidMetadata
        }
        return tensor
    }

    private func linear(_ input: [Float], weight weightName: String, bias biasName: String) throws -> [Float] {
        guard let weight = tensors[weightName], let bias = tensors[biasName],
              weight.shape.count == 2,
              weight.shape[1] == input.count,
              bias.shape == [weight.shape[0]],
              weight.values.count == weight.shape[0] * weight.shape[1] else {
            throw VFLY1Error.invalidMetadata
        }
        let outputCount = weight.shape[0], inputCount = weight.shape[1]
        var output = bias.values
        for row in 0..<outputCount {
            let base = row * inputCount
            var value = output[row]
            for column in 0..<inputCount { value += weight.values[base + column] * input[column] }
            output[row] = value
        }
        return output
    }

    private func layerNorm(_ input: [Float], weight weightName: String, bias biasName: String) throws -> [Float] {
        guard let weight = tensors[weightName], let bias = tensors[biasName],
              weight.shape == [input.count], bias.shape == [input.count], !input.isEmpty else {
            throw VFLY1Error.invalidMetadata
        }
        let count = Float(input.count), mean = input.reduce(0, +) / count
        var variance: Float = 0
        for value in input { let d = value - mean; variance += d * d }
        variance /= count
        let denominator = sqrt(variance + 1e-5)
        return input.indices.map { ((input[$0] - mean) / denominator) * weight.values[$0] + bias.values[$0] }
    }

    private func gelu(_ input: [Float]) -> [Float] {
        let inverseSqrtTwo = 1.0 / sqrt(2.0)
        return input.map { value in
            let x = Double(value)
            return Float(0.5 * x * (1.0 + erf(x * inverseSqrtTwo)))
        }
    }
}
