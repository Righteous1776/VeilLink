import Foundation

struct AgentActionScore: Equatable, Sendable {
    let actionID: String
    let score: Float
}

enum AgentGamePolicyError: LocalizedError, Equatable {
    case invalidMagic
    case unsupportedFormat(Int)
    case malformed(String)
    case unsupportedGame
    case missingTensor(String)
    case shapeMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidMagic: return "游戏策略模型格式无效。"
        case .unsupportedFormat(let value): return "不支持的游戏策略格式版本：\(value)。"
        case .malformed(let reason): return "游戏策略模型损坏：\(reason)"
        case .unsupportedGame: return "当前游戏没有启用训练策略。"
        case .missingTensor(let name): return "游戏策略模型缺少张量：\(name)"
        case .shapeMismatch(let name): return "游戏策略模型张量尺寸不匹配：\(name)"
        }
    }
}

/// Read-only inference runtime for the V0.9.0 self-play candidate ranker.
///
/// Security/gameplay boundary:
/// - only scores candidates already enumerated by an `AgentGameAdapter`;
/// - never mutates game state;
/// - never creates an action outside the engine's legal candidate set;
/// - Tactical / 三国兵棋 is intentionally unsupported in this model.
struct TrainedGamePolicyRuntime: Sendable {
    static let bundledResourceName = "game_policy_ranker_v4"
    static let bundledResourceExtension = "vlpol"
    static let formatMagic = Data("VLPOL1".utf8)

    private struct Tensor: Sendable {
        let shape: [Int]
        let values: [Float]
    }

    private let tensors: [String: Tensor]

    init(data: Data) throws {
        var reader = BinaryReader(data: data)
        guard try reader.readBytes(count: Self.formatMagic.count) == Self.formatMagic else {
            throw AgentGamePolicyError.invalidMagic
        }
        let format = Int(try reader.readUInt32())
        guard format == 1 else { throw AgentGamePolicyError.unsupportedFormat(format) }
        let tensorCount = Int(try reader.readUInt32())
        guard (1...64).contains(tensorCount) else {
            throw AgentGamePolicyError.malformed("tensor count")
        }
        var decoded: [String: Tensor] = [:]
        decoded.reserveCapacity(tensorCount)
        for _ in 0..<tensorCount {
            let nameLength = Int(try reader.readUInt16())
            guard nameLength > 0, nameLength <= 128,
                  let name = String(data: try reader.readBytes(count: nameLength), encoding: .utf8) else {
                throw AgentGamePolicyError.malformed("tensor name")
            }
            let rank = Int(try reader.readUInt8())
            guard (1...4).contains(rank) else { throw AgentGamePolicyError.malformed("tensor rank") }
            var shape: [Int] = []
            shape.reserveCapacity(rank)
            var expectedCount = 1
            for _ in 0..<rank {
                let dimension = Int(try reader.readUInt32())
                guard dimension > 0, dimension <= 1_000_000 else {
                    throw AgentGamePolicyError.malformed("tensor dimension")
                }
                shape.append(dimension)
                let multiplied = expectedCount.multipliedReportingOverflow(by: dimension)
                guard !multiplied.overflow else { throw AgentGamePolicyError.malformed("tensor size overflow") }
                expectedCount = multiplied.partialValue
            }
            let count = Int(try reader.readUInt32())
            guard count == expectedCount, count <= 2_000_000 else {
                throw AgentGamePolicyError.malformed("tensor element count")
            }
            var values = [Float]()
            values.reserveCapacity(count)
            for _ in 0..<count { values.append(try reader.readFloat32()) }
            guard decoded[name] == nil else { throw AgentGamePolicyError.malformed("duplicate tensor") }
            decoded[name] = Tensor(shape: shape, values: values)
        }
        guard reader.isAtEnd else { throw AgentGamePolicyError.malformed("trailing bytes") }
        tensors = decoded
        try validateArchitecture()
    }

    static func loadBundled(bundle: Bundle = .main) throws -> TrainedGamePolicyRuntime {
        let direct = bundle.url(forResource: bundledResourceName, withExtension: bundledResourceExtension)
        let nested = bundle.url(
            forResource: bundledResourceName,
            withExtension: bundledResourceExtension,
            subdirectory: "AgentModels"
        )
        guard let url = direct ?? nested else {
            throw AgentGamePolicyError.malformed("bundled model missing")
        }
        return try TrainedGamePolicyRuntime(data: Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    func scores(
        observation: AgentGameObservation,
        candidates: [AgentActionCandidate]
    ) throws -> [AgentActionScore] {
        guard let gameID = Self.gameID(for: observation.gameKind) else {
            throw AgentGamePolicyError.unsupportedGame
        }
        guard !candidates.isEmpty else { return [] }

        let stateInput = Self.dense(observation.features, count: 256)
        let state0 = try gelu(linear(stateInput, weight: "state.0.weight", bias: "state.0.bias"))
        let stateNorm = try layerNorm(state0, weight: "state.2.weight", bias: "state.2.bias")
        let stateHidden = try gelu(linear(stateNorm, weight: "state.3.weight", bias: "state.3.bias"))
        let embedding = try gameEmbedding(index: gameID)

        return try candidates.map { candidate in
            let actionInput = Self.dense(candidate.features, count: 16)
            let action0 = try gelu(linear(actionInput, weight: "action.0.weight", bias: "action.0.bias"))
            let actionNorm = try layerNorm(action0, weight: "action.2.weight", bias: "action.2.bias")
            let actionHidden = try gelu(linear(actionNorm, weight: "action.3.weight", bias: "action.3.bias"))
            let merged = stateHidden + actionHidden + embedding
            let head0 = try gelu(linear(merged, weight: "head.0.weight", bias: "head.0.bias"))
            let head1 = try gelu(linear(head0, weight: "head.3.weight", bias: "head.3.bias"))
            let output = try linear(head1, weight: "head.5.weight", bias: "head.5.bias")
            return AgentActionScore(actionID: candidate.actionID, score: output[0])
        }
    }

    func rankedLegalActions(adapter: any AgentGameAdapter) throws -> [AgentActionScore] {
        guard AgentGameRegistry.isTrainingEnabled(adapter.gameKind) else {
            throw AgentGamePolicyError.unsupportedGame
        }
        let candidates = adapter.enumerateLegalActions()
        let safeCandidates = candidates.filter(adapter.validate)
        let scored = try scores(observation: adapter.makeObservation(), candidates: safeCandidates)
        return scored.sorted {
            if $0.score == $1.score { return $0.actionID < $1.actionID }
            return $0.score > $1.score
        }
    }

    func bestLegalAction(adapter: any AgentGameAdapter) throws -> AgentActionCandidate? {
        let candidates = adapter.enumerateLegalActions().filter(adapter.validate)
        guard !candidates.isEmpty else { return nil }
        let ranked = try scores(observation: adapter.makeObservation(), candidates: candidates)
        guard let best = ranked.max(by: {
            if $0.score == $1.score { return $0.actionID > $1.actionID }
            return $0.score < $1.score
        }) else { return nil }
        return candidates.first(where: { $0.actionID == best.actionID })
    }

    private static func gameID(for kind: MiniGameKind) -> Int? {
        switch kind {
        case .gomoku: return 0
        case .xiangqi: return 1
        case .ludo: return 2
        case .tactical: return nil
        }
    }

    private static func dense(_ features: [AgentFeature], count: Int) -> [Float] {
        var values = Array(features.prefix(count).map(\.value))
        if values.count < count { values.append(contentsOf: repeatElement(0, count: count - values.count)) }
        return values
    }

    private func gameEmbedding(index: Int) throws -> [Float] {
        let tensor = try required("game.weight")
        guard tensor.shape == [3, 24], (0..<3).contains(index) else {
            throw AgentGamePolicyError.shapeMismatch("game.weight")
        }
        let start = index * 24
        return Array(tensor.values[start..<(start + 24)])
    }

    private func linear(_ input: [Float], weight weightName: String, bias biasName: String) throws -> [Float] {
        let weight = try required(weightName)
        let bias = try required(biasName)
        guard weight.shape.count == 2 else { throw AgentGamePolicyError.shapeMismatch(weightName) }
        let outputCount = weight.shape[0]
        let inputCount = weight.shape[1]
        guard input.count == inputCount, bias.shape == [outputCount] else {
            throw AgentGamePolicyError.shapeMismatch(weightName)
        }
        var output = bias.values
        for row in 0..<outputCount {
            let base = row * inputCount
            var value = output[row]
            for column in 0..<inputCount {
                value += weight.values[base + column] * input[column]
            }
            output[row] = value
        }
        return output
    }

    private func layerNorm(_ input: [Float], weight weightName: String, bias biasName: String) throws -> [Float] {
        let weight = try required(weightName)
        let bias = try required(biasName)
        guard weight.shape == [input.count], bias.shape == [input.count], !input.isEmpty else {
            throw AgentGamePolicyError.shapeMismatch(weightName)
        }
        let count = Float(input.count)
        let mean = input.reduce(0, +) / count
        var variance: Float = 0
        for value in input {
            let delta = value - mean
            variance += delta * delta
        }
        variance /= count
        let denominator = sqrt(variance + 1e-5)
        var output = [Float](repeating: 0, count: input.count)
        for index in input.indices {
            output[index] = ((input[index] - mean) / denominator) * weight.values[index] + bias.values[index]
        }
        return output
    }

    private func gelu(_ input: [Float]) -> [Float] {
        let inverseSqrtTwo = 1.0 / sqrt(2.0)
        return input.map { value in
            let x = Double(value)
            return Float(0.5 * x * (1.0 + erf(x * inverseSqrtTwo)))
        }
    }

    private func required(_ name: String) throws -> Tensor {
        guard let tensor = tensors[name] else { throw AgentGamePolicyError.missingTensor(name) }
        return tensor
    }

    private func validateArchitecture() throws {
        let shapes: [String: [Int]] = [
            "game.weight": [3, 24],
            "state.0.weight": [320, 256], "state.0.bias": [320],
            "state.2.weight": [320], "state.2.bias": [320],
            "state.3.weight": [192, 320], "state.3.bias": [192],
            "action.0.weight": [96, 16], "action.0.bias": [96],
            "action.2.weight": [96], "action.2.bias": [96],
            "action.3.weight": [80, 96], "action.3.bias": [80],
            "head.0.weight": [160, 296], "head.0.bias": [160],
            "head.3.weight": [64, 160], "head.3.bias": [64],
            "head.5.weight": [1, 64], "head.5.bias": [1]
        ]
        for (name, shape) in shapes {
            guard let tensor = tensors[name] else { throw AgentGamePolicyError.missingTensor(name) }
            guard tensor.shape == shape else { throw AgentGamePolicyError.shapeMismatch(name) }
        }
    }
}

private struct BinaryReader {
    let data: Data
    private(set) var offset: Int = 0
    var isAtEnd: Bool { offset == data.count }

    mutating func readUInt8() throws -> UInt8 {
        let bytes = try readBytes(count: 1)
        return bytes[bytes.startIndex]
    }

    mutating func readUInt16() throws -> UInt16 {
        let bytes = try readBytes(count: 2)
        return UInt16(bytes[bytes.startIndex]) | (UInt16(bytes[bytes.startIndex + 1]) << 8)
    }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try readBytes(count: 4)
        return UInt32(bytes[bytes.startIndex])
            | (UInt32(bytes[bytes.startIndex + 1]) << 8)
            | (UInt32(bytes[bytes.startIndex + 2]) << 16)
            | (UInt32(bytes[bytes.startIndex + 3]) << 24)
    }

    mutating func readFloat32() throws -> Float {
        Float(bitPattern: try readUInt32())
    }

    mutating func readBytes(count: Int) throws -> Data {
        guard count >= 0, offset <= data.count, count <= data.count - offset else {
            throw AgentGamePolicyError.malformed("unexpected end of file")
        }
        let range = offset..<(offset + count)
        offset += count
        return data.subdata(in: range)
    }
}
