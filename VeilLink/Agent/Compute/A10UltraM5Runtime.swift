import CryptoKit
import Foundation

private struct A10UltraM5ArrayDescriptor: Decodable {
    let offset: Int
    let bytes: Int
    let count: Int
    let shape: [Int]
    let sha256: String
}

private struct A10UltraM5IOSManifest: Decodable {
    let schema: String
    let chip_name: String
    let engineering_source: String
    let state: String
    let source_model_hash: String
    let source_arrays_hash: String
    let flat_language_weights_sha256: String
    let vocab_sha256: String
    let arrays: [String: A10UltraM5ArrayDescriptor]
    let predictor_model_id: String
    let predictor_weights_sha256: String
    let sqlite_predictor_model_id: String
    let sqlite_predictor_model_hash: String
    let sqlite_predictor_weights_sha256: String
    let native_abi: String
    let mutation_authority: Int
    let production_cutover: String
    let real_world_validation: String
}

private struct A10UltraM5Vocab: Decodable {
    let tokens: [String]
    let reasoning_states: [String]
}

private struct A10UltraM5SourceModelManifest: Decodable {
    let model_id: String
    let model_version: String
    let weights_sha256_arrays: String
    let vocab_sha256: String
    let mutation_authority: Int
    let deployment_mode: String
    let real_world_validation: String
    let model_sha256: String
}

private struct A10UltraM5PredictorSection: Decodable {
    let rows: Int
    let cols: Int
    let fp32_weight_offset: Int
    let fp32_weight_bytes: Int
    let int8_weight_offset: Int
    let int8_weight_bytes: Int
    let bias_offset: Int
    let bias_bytes: Int
    let weight_scale: Float
    let weight_zero_point: Int32
}

private struct A10UltraM5PredictorInputQuantization: Decodable {
    let scale: Float
    let zero_point: Int32
}

private struct A10UltraM5PredictorQuantization: Decodable {
    let input: A10UltraM5PredictorInputQuantization
}

private struct A10UltraM5PredictorManifest: Decodable {
    let model_id: String
    let weight_sha256: String
    let output_labels: [String]
    let mutation_authority: Int
    let deployment_mode: String
    let real_world_validation: String
    let model_sha256: String
    let sections: [String: A10UltraM5PredictorSection]
    let quantization: A10UltraM5PredictorQuantization
}

private struct A10UltraM5Assets {
    let integration: A10UltraM5IOSManifest
    let sourceModel: A10UltraM5SourceModelManifest
    let vocab: [String]
    let ids: [String: Int]
    let reasoningStates: [String]

    let E: [Float]
    let W: [Float]
    let bh: [Float]
    let O: [Float]
    let bo: [Float]
    let C: [Float]
    let RA: [Float]
    let Rab: [Float]
    let RB: [Float]
    let Rbb: [Float]

    let predictorW1: [Float]
    let predictorB1: [Float]
    let predictorW2: [Float]
    let predictorB2: [Float]
    let predictorW3: [Float]
    let predictorB3: [Float]
    let predictorLabels: [String]
    let predictorW1I8: [Int8]
    let predictorW2I8: [Int8]
    let predictorW3I8: [Int8]
    let predictorW1Scale: Float
    let predictorW2Scale: Float
    let predictorW3Scale: Float
    let predictorW1ZeroPoint: Int32
    let predictorW2ZeroPoint: Int32
    let predictorW3ZeroPoint: Int32
    let predictorInputScale: Float
    let predictorInputZeroPoint: Int32

    let sqlitePredictorW1: [Float]
    let sqlitePredictorB1: [Float]
    let sqlitePredictorW2: [Float]
    let sqlitePredictorB2: [Float]
    let sqlitePredictorW3: [Float]
    let sqlitePredictorB3: [Float]
    let sqlitePredictorLabels: [String]
    let sqlitePredictorW1I8: [Int8]
    let sqlitePredictorW2I8: [Int8]
    let sqlitePredictorW3I8: [Int8]
    let sqlitePredictorW1Scale: Float
    let sqlitePredictorW2Scale: Float
    let sqlitePredictorW3Scale: Float
    let sqlitePredictorW1ZeroPoint: Int32
    let sqlitePredictorW2ZeroPoint: Int32
    let sqlitePredictorW3ZeroPoint: Int32
    let sqlitePredictorInputScale: Float
    let sqlitePredictorInputZeroPoint: Int32

    static func load(bundle: Bundle = .main) throws -> A10UltraM5Assets {
        func assetURL(_ name: String, _ ext: String) throws -> URL {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "A10UltraM5") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
            throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 缺少资源：\(name).\(ext)")
        }

        let integrationData = try Data(contentsOf: assetURL("ios_integration_manifest", "json"))
        let integration = try JSONDecoder().decode(A10UltraM5IOSManifest.self, from: integrationData)
        guard integration.schema == "VEILLINK_A10_ULTRA_M5_IOS_ASSET_V1",
              integration.chip_name == "A10 Ultra Ω",
              integration.state == "TRAINED_COGNITION_SHADOW",
              integration.mutation_authority == 0,
              integration.production_cutover == "DENY",
              integration.real_world_validation == "NOT_PERFORMED",
              integration.native_abi == "A10_ULTRA_M5_IOS_NATIVE_V1" else {
            throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 iOS 集成合同不匹配。")
        }

        let sourceModelData = try Data(contentsOf: assetURL("model", "json"))
        let sourceModel = try JSONDecoder().decode(A10UltraM5SourceModelManifest.self, from: sourceModelData)
        guard sourceModel.model_id == "OMEGA96_MICRO_LANGUAGE_REASONER_M5",
              sourceModel.model_sha256 == integration.source_model_hash,
              sourceModel.weights_sha256_arrays == integration.source_arrays_hash,
              sourceModel.vocab_sha256 == integration.vocab_sha256,
              sourceModel.mutation_authority == 0,
              sourceModel.deployment_mode == "SHADOW_ONLY",
              sourceModel.real_world_validation == "NOT_PERFORMED" else {
            throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 源模型 provenance 校验失败。")
        }

        let vocabData = try Data(contentsOf: assetURL("vocab", "json"))
        guard Self.sha256(vocabData) == integration.vocab_sha256 else {
            throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 词表哈希不匹配。")
        }
        let decodedVocab = try JSONDecoder().decode(A10UltraM5Vocab.self, from: vocabData)
        guard decodedVocab.tokens.count == 69, decodedVocab.reasoning_states.count == 11 else {
            throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 词表维度错误。")
        }

        let weights = try Data(contentsOf: assetURL("language_weights", "bin"))
        guard Self.sha256(weights) == integration.flat_language_weights_sha256,
              integration.flat_language_weights_sha256 == integration.source_arrays_hash else {
            throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 语言权重哈希不匹配。")
        }

        func array(_ name: String) throws -> [Float] {
            guard let descriptor = integration.arrays[name],
                  descriptor.bytes == descriptor.count * MemoryLayout<Float>.size,
                  descriptor.offset >= 0,
                  descriptor.offset + descriptor.bytes <= weights.count else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 数组布局无效：\(name)")
            }
            let range = descriptor.offset..<(descriptor.offset + descriptor.bytes)
            let data = weights.subdata(in: range)
            guard Self.sha256(data) == descriptor.sha256 else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 数组哈希不匹配：\(name)")
            }
            return Self.floatArray(data: data, count: descriptor.count)
        }

        let predictorManifestData = try Data(contentsOf: assetURL("runtime_predictor_model", "json"))
        let predictorManifest = try JSONDecoder().decode(A10UltraM5PredictorManifest.self, from: predictorManifestData)
        let predictorWeights = try Data(contentsOf: assetURL("runtime_predictor_weights", "bin"))
        guard predictorManifest.model_id == integration.predictor_model_id,
              predictorManifest.weight_sha256 == integration.predictor_weights_sha256,
              Self.sha256(predictorWeights) == integration.predictor_weights_sha256,
              predictorManifest.mutation_authority == 0,
              predictorManifest.deployment_mode == "SHADOW_ONLY",
              predictorManifest.real_world_validation == "NOT_PERFORMED" else {
            throw A10UltraComputeError.unavailable("A10 Ultra Ω M4 Runtime Predictor provenance 校验失败。")
        }

        func predictorArray(_ sectionName: String, weight: Bool) throws -> [Float] {
            guard let section = predictorManifest.sections[sectionName] else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω M4 缺少层：\(sectionName)")
            }
            let offset = weight ? section.fp32_weight_offset : section.bias_offset
            let byteCount = weight ? section.fp32_weight_bytes : section.bias_bytes
            guard offset >= 0, byteCount > 0, offset + byteCount <= predictorWeights.count else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω M4 层布局无效：\(sectionName)")
            }
            return Self.floatArray(
                data: predictorWeights.subdata(in: offset..<(offset + byteCount)),
                count: byteCount / MemoryLayout<Float>.size
            )
        }

        func predictorInt8(_ sectionName: String) throws -> [Int8] {
            guard let section = predictorManifest.sections[sectionName] else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω M4 缺少 INT8 层：\(sectionName)")
            }
            guard section.int8_weight_offset >= 0, section.int8_weight_bytes > 0,
                  section.int8_weight_offset + section.int8_weight_bytes <= predictorWeights.count else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω M4 INT8 层布局无效：\(sectionName)")
            }
            return Self.int8Array(
                data: predictorWeights.subdata(in: section.int8_weight_offset..<(section.int8_weight_offset + section.int8_weight_bytes))
            )
        }

        let sqlitePredictorManifestData = try Data(contentsOf: assetURL("sqlite_predictor_model", "json"))
        let sqlitePredictorManifest = try JSONDecoder().decode(A10UltraM5PredictorManifest.self, from: sqlitePredictorManifestData)
        let sqlitePredictorWeights = try Data(contentsOf: assetURL("sqlite_predictor_weights", "bin"))
        guard sqlitePredictorManifest.model_id == integration.sqlite_predictor_model_id,
              sqlitePredictorManifest.model_sha256 == integration.sqlite_predictor_model_hash,
              sqlitePredictorManifest.weight_sha256 == integration.sqlite_predictor_weights_sha256,
              Self.sha256(sqlitePredictorWeights) == integration.sqlite_predictor_weights_sha256,
              sqlitePredictorManifest.mutation_authority == 0,
              sqlitePredictorManifest.deployment_mode == "SHADOW_ONLY",
              sqlitePredictorManifest.real_world_validation == "NOT_PERFORMED" else {
            throw A10UltraComputeError.unavailable("A10 Ultra Ω SQLite M4 Predictor provenance 校验失败。")
        }

        func sqlitePredictorArray(_ sectionName: String, weight: Bool) throws -> [Float] {
            guard let section = sqlitePredictorManifest.sections[sectionName] else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω SQLite M4 缺少层：\(sectionName)")
            }
            let offset = weight ? section.fp32_weight_offset : section.bias_offset
            let byteCount = weight ? section.fp32_weight_bytes : section.bias_bytes
            guard offset >= 0, byteCount > 0, offset + byteCount <= sqlitePredictorWeights.count else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω SQLite M4 层布局无效：\(sectionName)")
            }
            return Self.floatArray(
                data: sqlitePredictorWeights.subdata(in: offset..<(offset + byteCount)),
                count: byteCount / MemoryLayout<Float>.size
            )
        }

        func sqlitePredictorInt8(_ sectionName: String) throws -> [Int8] {
            guard let section = sqlitePredictorManifest.sections[sectionName] else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω SQLite M4 缺少 INT8 层：\(sectionName)")
            }
            guard section.int8_weight_offset >= 0, section.int8_weight_bytes > 0,
                  section.int8_weight_offset + section.int8_weight_bytes <= sqlitePredictorWeights.count else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω SQLite M4 INT8 层布局无效：\(sectionName)")
            }
            return Self.int8Array(
                data: sqlitePredictorWeights.subdata(in: section.int8_weight_offset..<(section.int8_weight_offset + section.int8_weight_bytes))
            )
        }

        let ids = Dictionary(uniqueKeysWithValues: decodedVocab.tokens.enumerated().map { ($0.element, $0.offset) })
        return A10UltraM5Assets(
            integration: integration,
            sourceModel: sourceModel,
            vocab: decodedVocab.tokens,
            ids: ids,
            reasoningStates: decodedVocab.reasoning_states,
            E: try array("E"),
            W: try array("W"),
            bh: try array("bh"),
            O: try array("O"),
            bo: try array("bo"),
            C: try array("C"),
            RA: try array("RA"),
            Rab: try array("Rab"),
            RB: try array("RB"),
            Rbb: try array("Rbb"),
            predictorW1: try predictorArray("dense1", weight: true),
            predictorB1: try predictorArray("dense1", weight: false),
            predictorW2: try predictorArray("dense2", weight: true),
            predictorB2: try predictorArray("dense2", weight: false),
            predictorW3: try predictorArray("dense3", weight: true),
            predictorB3: try predictorArray("dense3", weight: false),
            predictorLabels: predictorManifest.output_labels,
            predictorW1I8: try predictorInt8("dense1"),
            predictorW2I8: try predictorInt8("dense2"),
            predictorW3I8: try predictorInt8("dense3"),
            predictorW1Scale: predictorManifest.sections["dense1"]?.weight_scale ?? 0,
            predictorW2Scale: predictorManifest.sections["dense2"]?.weight_scale ?? 0,
            predictorW3Scale: predictorManifest.sections["dense3"]?.weight_scale ?? 0,
            predictorW1ZeroPoint: predictorManifest.sections["dense1"]?.weight_zero_point ?? 0,
            predictorW2ZeroPoint: predictorManifest.sections["dense2"]?.weight_zero_point ?? 0,
            predictorW3ZeroPoint: predictorManifest.sections["dense3"]?.weight_zero_point ?? 0,
            predictorInputScale: predictorManifest.quantization.input.scale,
            predictorInputZeroPoint: predictorManifest.quantization.input.zero_point,
            sqlitePredictorW1: try sqlitePredictorArray("dense1", weight: true),
            sqlitePredictorB1: try sqlitePredictorArray("dense1", weight: false),
            sqlitePredictorW2: try sqlitePredictorArray("dense2", weight: true),
            sqlitePredictorB2: try sqlitePredictorArray("dense2", weight: false),
            sqlitePredictorW3: try sqlitePredictorArray("dense3", weight: true),
            sqlitePredictorB3: try sqlitePredictorArray("dense3", weight: false),
            sqlitePredictorLabels: sqlitePredictorManifest.output_labels,
            sqlitePredictorW1I8: try sqlitePredictorInt8("dense1"),
            sqlitePredictorW2I8: try sqlitePredictorInt8("dense2"),
            sqlitePredictorW3I8: try sqlitePredictorInt8("dense3"),
            sqlitePredictorW1Scale: sqlitePredictorManifest.sections["dense1"]?.weight_scale ?? 0,
            sqlitePredictorW2Scale: sqlitePredictorManifest.sections["dense2"]?.weight_scale ?? 0,
            sqlitePredictorW3Scale: sqlitePredictorManifest.sections["dense3"]?.weight_scale ?? 0,
            sqlitePredictorW1ZeroPoint: sqlitePredictorManifest.sections["dense1"]?.weight_zero_point ?? 0,
            sqlitePredictorW2ZeroPoint: sqlitePredictorManifest.sections["dense2"]?.weight_zero_point ?? 0,
            sqlitePredictorW3ZeroPoint: sqlitePredictorManifest.sections["dense3"]?.weight_zero_point ?? 0,
            sqlitePredictorInputScale: sqlitePredictorManifest.quantization.input.scale,
            sqlitePredictorInputZeroPoint: sqlitePredictorManifest.quantization.input.zero_point
        )
    }

    private static func floatArray(data: Data, count: Int) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        output.withUnsafeMutableBytes { destination in
            _ = data.copyBytes(to: destination)
        }
        #if _endian(big)
        for index in output.indices {
            output[index] = Float(bitPattern: output[index].bitPattern.byteSwapped)
        }
        #endif
        return output
    }

    private static func int8Array(data: Data) -> [Int8] {
        data.map { Int8(bitPattern: $0) }
    }

    fileprivate static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct A10UltraM5Inference: Equatable, Sendable {
    let text: String
    let states: [String]
    let probabilities: [Double]
    let generatedTokens: [String]
    let latencyNanoseconds: UInt64
    let modelHash: String
    let inputDigest: String
    let outputDigest: String
    let backend: String
    let mutationAuthority: Int
}

@MainActor
final class A10UltraM5Runtime: A10UltraComputeRuntime {
    private(set) var state: A10UltraComputeState = .unloaded
    let manifest = A10UltraComputeManifest(
        runtimeID: "a10-ultra-omega.m5.micro-language-reasoning.ios-shadow",
        displayName: "A10 Ultra Ω M5 Micro Language Reasoning",
        abiVersion: 1,
        artifactDigest: "c5ba826dab1ebe1db02e90e8b4bfd2c060e99586413970fa3bd4d848e378a8b4",
        supportedTasks: [.textGeneration, .structuredReasoning],
        supportsStreaming: true,
        supportsCancellation: true,
        supportsStateSnapshot: true,
        minimumOSMajor: 15,
        notes: "M5 trained synthetic-domain cognition; SHADOW_ONLY; mutation_authority=0"
    )

    private var assets: A10UltraM5Assets?
    private var budget: A10UltraComputeBudget?
    private var cancellationEpoch = 0
    private var inferenceEpoch: UInt64 = 0

    private static let backend = "A10_ULTRA_OMEGA_M5_IOS_PORTABLE_C_V1"
    private static let stateNames = [
        "S_LINK_BAD", "S_RECONNECT", "S_QUEUE", "S_THERMAL", "S_DB_STALL", "S_RESOURCE",
        "S_NORMAL", "S_SUSPICIOUS", "S_CORRUPTED", "S_HIGH_RISK", "S_UNKNOWN"
    ]

    private static let phrases: [(String, [String])] = [
        ("丢包", ["W_PACKET", "W_LOSS"]), ("重连", ["W_RECONNECT"]), ("队列", ["W_QUEUE"]),
        ("拥塞", ["W_BLOCKED"]), ("堵", ["W_BLOCKED"]), ("发烫", ["W_HOT", "W_THERMAL"]),
        ("温度", ["W_THERMAL"]), ("热", ["W_HOT"]), ("数据库", ["W_DATABASE"]),
        ("SQLite", ["W_DATABASE"]), ("损坏", ["W_CORRUPTED"]), ("可疑", ["W_SUSPICIOUS"]),
        ("高风险", ["W_RISK"]), ("正常", ["W_NORMAL"]), ("未知", ["W_UNKNOWN"]),
        ("资源", ["W_RESOURCE"]), ("内存", ["W_RESOURCE"]), ("CPU", ["W_RESOURCE"]),
        ("不足", ["W_LOW"]), ("低", ["W_LOW"]), ("链路", ["W_LINK"]),
        ("蓝牙", ["W_LINK"]), ("弱", ["W_WEAK"]), ("差", ["W_WEAK"]), ("慢", ["W_SLOW"]),
        ("卡", ["W_SLOW"])
    ]

    private static let render: [String: String] = [
        "THINK":"分析：", "ANSWER":"建议：", "S_LINK_BAD":"链路退化，", "S_RECONNECT":"重连风险，",
        "S_QUEUE":"队列拥塞，", "S_THERMAL":"热压力，", "S_DB_STALL":"数据库迟滞，", "S_RESOURCE":"资源压力，",
        "S_NORMAL":"状态正常，", "S_SUSPICIOUS":"存在可疑信号，", "S_CORRUPTED":"可能损坏，", "S_HIGH_RISK":"高风险状态，",
        "S_UNKNOWN":"信息不足，", "T_CHECK_LINK":"检查链路与丢包。", "T_CHECK_RETRY":"核对重试和重连。",
        "T_CHECK_QUEUE":"检查队列积压。", "T_CHECK_THERMAL":"检查温度和负载。", "T_CHECK_DB":"检查数据库延迟。",
        "T_CHECK_RESOURCE":"检查资源余量。", "T_VERIFY_NORMAL":"复核完整性信号。", "T_VERIFY_SCHEMA":"复核结构异常。",
        "T_VERIFY_INTEGRITY":"执行只读完整性检查。", "T_ISOLATE_RISK":"隔离高风险来源。", "T_COLLECT_MORE":"补充观测数据。",
        "A_OBSERVE":"继续观察，", "A_REDUCE_RATE":"暂时降低发送速率，", "A_RECONNECT_REVIEW":"进入重连复核，",
        "A_DRAIN_QUEUE":"先消化队列，", "A_COOL_DOWN":"降低算力并冷却，", "A_DB_REVIEW":"进入数据库复核，",
        "A_CONSERVE":"保留传输与计算资源，", "A_NO_ACTION":"暂不处置，", "A_SCHEMA_REVIEW":"检查结构与索引，",
        "A_QUARANTINE_COPY":"隔离副本后检查，", "A_BACKUP_FIRST":"先备份再复核，", "A_NEED_MORE":"请补充状态，",
        "A_READ_ONLY":"保持只读与观察。"
    ]

    func prepare() async throws {
        guard state == .unloaded || state == .failed else { return }
        state = .loading
        do {
            guard a10_ultra_m5_native_abi_version() == 1 else {
                throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 Native ABI 不匹配。")
            }
            assets = try A10UltraM5Assets.load()
            state = .ready
        } catch {
            state = .failed
            throw error
        }
    }

    func generateText(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult {
        try await prepareIfNeeded()
        guard !request.userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw A10UltraComputeError.invalidRequest("M5 Shadow 输入为空。")
        }
        let epoch = cancellationEpoch
        state = .computing
        defer { if state == .computing { state = .ready } }

        let features = A10UltraM5FeatureAdapter.features(from: request.localContext)
        let inference = try infer(text: request.userText, domain: nil, hostFeatures: features)
        let chunks = Self.streamChunks(inference.text, targetCharacters: 4)
        var emitted = 0
        for chunk in chunks {
            try Task.checkCancellation()
            guard epoch == cancellationEpoch else { throw A10UltraComputeError.cancelled }
            onToken(chunk)
            emitted += 1
            await Task.yield()
        }
        return AgentTextResult(
            text: inference.text,
            emittedChunkCount: emitted,
            estimatedTokenCount: max(1, inference.generatedTokens.count)
        )
    }

    func execute(_ request: A10UltraComputeRequest) async throws -> A10UltraComputeResponse {
        guard request.task == .structuredReasoning || request.task == .textGeneration else {
            throw A10UltraComputeError.unsupported(request.task)
        }
        try await prepareIfNeeded()
        guard let text = request.textInputs.first, !text.isEmpty else {
            throw A10UltraComputeError.invalidRequest("M5 reasoning 需要文本输入。")
        }
        let features: [Float]?
        if (0..<32).allSatisfy({ request.numericInputs["f\($0)"] != nil }) {
            features = (0..<32).map { Float(request.numericInputs["f\($0)"] ?? 0) }
        } else {
            features = nil
        }
        state = .computing
        defer { if state == .computing { state = .ready } }
        let inference = try infer(text: text, domain: request.metadata["domain"], hostFeatures: features)
        var numeric: [String: Double] = [:]
        for (index, value) in inference.probabilities.enumerated() {
            numeric["state_probability_\(index)"] = value
        }
        return A10UltraComputeResponse(
            jobID: request.jobID,
            textOutputs: [inference.text],
            numericOutputs: numeric,
            opaquePayload: nil,
            runtimeMetadata: [
                "states": inference.states.joined(separator: ","),
                "generated_tokens": inference.generatedTokens.joined(separator: ","),
                "backend": inference.backend,
                "model_hash": inference.modelHash,
                "input_digest": inference.inputDigest,
                "output_digest": inference.outputDigest,
                "latency_ns": String(inference.latencyNanoseconds),
                "recommendation": "SHADOW_ADVISORY_ONLY",
                "mutation_authority": "0",
                "real_world_validation": "NOT_PERFORMED"
            ]
        )
    }

    func applyBudget(_ budget: A10UltraComputeBudget) {
        self.budget = budget
        if budget.totalUnits <= 0, state == .ready { state = .cooling }
        if budget.totalUnits > 0, state == .cooling { state = .ready }
    }

    func cancel() {
        cancellationEpoch &+= 1
        if state == .computing || state == .loading { state = .ready }
    }

    func trimMemory() {
        // Keep the tiny verified model resident; only transient buffers are stack/local.
    }

    func unload() {
        cancellationEpoch &+= 1
        assets = nil
        state = .unloaded
    }

    func infer(
        text: String,
        domain: String?,
        hostFeatures: [Float]? = nil,
        threshold: Float = 0.5
    ) throws -> A10UltraM5Inference {
        guard let assets else { throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 尚未载入。") }
        let started = DispatchTime.now().uptimeNanoseconds
        let resolvedDomain = resolveDomain(text: text, explicit: domain)
        let prefix = tokenize(text: text, domain: resolvedDomain, assets: assets)
        let probabilities = try reason(prefix: prefix, assets: assets)
        let semantic = prefix.contains { id in
            let token = assets.vocab[id]
            return token.hasPrefix("W_") && !["W_HOW", "W_WHY", "W_NOW"].contains(token)
        }
        var states: [String] = semantic && resolvedDomain != "D_UNKNOWN" ? [] : ["S_UNKNOWN"]
        if states.isEmpty {
            states = Self.stateNames.enumerated().compactMap { index, name in
                probabilities[index] >= threshold ? name : nil
            }
        }

        if let hostFeatures, hostFeatures.count == 32, resolvedDomain == "D_VEIL" {
            let hostScores = try hostPredictor(features: hostFeatures, assets: assets)
            let mapping = Array(Self.stateNames.prefix(6))
            for (index, value) in hostScores.prefix(6).enumerated() where value >= 0.6 {
                states.append(mapping[index])
            }
        } else if let hostFeatures, hostFeatures.count == 32, resolvedDomain == "D_SQLITE" {
            let sqliteScores = try sqlitePredictor(features: hostFeatures, assets: assets)
            let predicted = sqliteScores.indices.max(by: { sqliteScores[$0] < sqliteScores[$1] }) ?? 4
            let mappedState = predicted < 5 ? Self.stateNames[6 + predicted] : "S_UNKNOWN"
            states.append(mappedState)
        }
        var uniqueStates: [String] = []
        for state in states where !uniqueStates.contains(state) { uniqueStates.append(state) }
        states = uniqueStates
        if states.isEmpty { states = ["S_UNKNOWN"] }

        let qTokenName: String = {
            guard prefix.count >= 3 else { return "Q_STATUS" }
            let candidate = assets.vocab[prefix[prefix.count - 3]]
            return candidate.hasPrefix("Q_") ? candidate : "Q_STATUS"
        }()

        var generated: [String] = []
        for stateName in states {
            let clauseDomain: String
            if resolvedDomain != "D_UNKNOWN" {
                clauseDomain = resolvedDomain
            } else {
                clauseDomain = ["S_NORMAL", "S_SUSPICIOUS", "S_CORRUPTED", "S_HIGH_RISK", "S_UNKNOWN"].contains(stateName)
                    ? "D_SQLITE" : "D_VEIL"
            }
            generated.append(contentsOf: try generateClause(
                domain: clauseDomain,
                state: stateName,
                question: qTokenName,
                assets: assets
            ))
        }

        let rendered = generated.map { Self.render[$0] ?? "" }.joined()
        inferenceEpoch &+= 1
        var inputData = Data(text.utf8)
        inputData.append(0)
        inputData.append(contentsOf: prefix.map { UInt8(clamping: $0) })
        var outputData = Data(rendered.utf8)
        outputData.append(0)
        outputData.append(Data(generated.joined(separator: "|").utf8))
        let latency = DispatchTime.now().uptimeNanoseconds &- started
        return A10UltraM5Inference(
            text: rendered,
            states: states,
            probabilities: probabilities.map(Double.init),
            generatedTokens: generated,
            latencyNanoseconds: latency,
            modelHash: assets.sourceModel.model_sha256,
            inputDigest: A10UltraM5Assets.sha256(inputData),
            outputDigest: A10UltraM5Assets.sha256(outputData),
            backend: Self.backend,
            mutationAuthority: 0
        )
    }

    private func prepareIfNeeded() async throws {
        if let budget, budget.totalUnits <= 0 {
            if assets != nil, state == .ready { state = .cooling }
            throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 当前计算预算为 0；Shadow 推理已被治理层抑制。")
        }
        if state == .unloaded || state == .failed { try await prepare() }
        guard state == .ready || state == .cooling else {
            throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 当前状态：\(state.rawValue)")
        }
    }

    private func resolveDomain(text: String, explicit: String?) -> String {
        if let explicit {
            let lower = explicit.lowercased()
            if lower.hasPrefix("sqlite") { return "D_SQLITE" }
            if lower.hasPrefix("veil") { return "D_VEIL" }
        }
        if text.contains("数据库") || text.contains("SQLite") { return "D_SQLITE" }
        if ["链路", "蓝牙", "丢包", "重连", "队列"].contains(where: text.contains) { return "D_VEIL" }
        return "D_UNKNOWN"
    }

    private func tokenize(text: String, domain: String, assets: A10UltraM5Assets) -> [Int] {
        var names = ["BOS", domain]
        for (phrase, tokens) in Self.phrases where text.contains(phrase) { names.append(contentsOf: tokens) }
        if text.contains("为什么") || text.contains("原因") {
            names.append(contentsOf: ["Q_CAUSE", "W_WHY"])
        } else if text.contains("怎么办") || text.contains("如何") || text.contains("建议") {
            names.append(contentsOf: ["Q_ACTION", "W_HOW"])
        } else if text.contains("总结") {
            names.append(contentsOf: ["Q_SUMMARY", "W_NOW"])
        } else {
            names.append(contentsOf: ["Q_STATUS", "W_NOW"])
        }
        names.append("SEP")
        return names.compactMap { assets.ids[$0] }
    }

    private func reason(prefix: [Int], assets: A10UltraM5Assets) throws -> [Float] {
        var bag = [Float](repeating: 0, count: 69)
        for id in Set(prefix) where bag.indices.contains(id) { bag[id] = 1 }
        var hidden = [Float](repeating: 0, count: 64)
        var output = [Float](repeating: 0, count: 11)
        let rc = bag.withUnsafeBufferPointer { input in
            assets.RA.withUnsafeBufferPointer { ra in
                assets.Rab.withUnsafeBufferPointer { rab in
                    assets.RB.withUnsafeBufferPointer { rb in
                        assets.Rbb.withUnsafeBufferPointer { rbb in
                            hidden.withUnsafeMutableBufferPointer { h in
                                output.withUnsafeMutableBufferPointer { o in
                                    a10_ultra_m5_reasoner_f32(
                                        input.baseAddress, ra.baseAddress, rab.baseAddress, rb.baseAddress, rbb.baseAddress,
                                        h.baseAddress, o.baseAddress
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        guard rc == 0 else { throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 Reasoner Native 错误：\(rc)") }
        return output
    }

    private func hostPredictor(features: [Float], assets: A10UltraM5Assets) throws -> [Float] {
        var output = [Float](repeating: 0, count: 8)
        let rc = features.withUnsafeBufferPointer { input in
            assets.predictorW1I8.withUnsafeBufferPointer { w1 in
                assets.predictorB1.withUnsafeBufferPointer { b1 in
                    assets.predictorW2I8.withUnsafeBufferPointer { w2 in
                        assets.predictorB2.withUnsafeBufferPointer { b2 in
                            assets.predictorW3I8.withUnsafeBufferPointer { w3 in
                                assets.predictorB3.withUnsafeBufferPointer { b3 in
                                    output.withUnsafeMutableBufferPointer { out in
                                        a10_ultra_m5_host_predictor_i8(
                                            input.baseAddress,
                                            w1.baseAddress, assets.predictorW1Scale, assets.predictorW1ZeroPoint, b1.baseAddress,
                                            w2.baseAddress, assets.predictorW2Scale, assets.predictorW2ZeroPoint, b2.baseAddress,
                                            w3.baseAddress, assets.predictorW3Scale, assets.predictorW3ZeroPoint, b3.baseAddress,
                                            assets.predictorInputScale, assets.predictorInputZeroPoint,
                                            out.baseAddress
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        guard rc == 0 else { throw A10UltraComputeError.unavailable("A10 Ultra Ω M4 INT8 Predictor Native 错误：\(rc)") }
        return output
    }

    private func sqlitePredictor(features: [Float], assets: A10UltraM5Assets) throws -> [Float] {
        var output = [Float](repeating: 0, count: 8)
        let rc = features.withUnsafeBufferPointer { input in
            assets.sqlitePredictorW1I8.withUnsafeBufferPointer { w1 in
                assets.sqlitePredictorB1.withUnsafeBufferPointer { b1 in
                    assets.sqlitePredictorW2I8.withUnsafeBufferPointer { w2 in
                        assets.sqlitePredictorB2.withUnsafeBufferPointer { b2 in
                            assets.sqlitePredictorW3I8.withUnsafeBufferPointer { w3 in
                                assets.sqlitePredictorB3.withUnsafeBufferPointer { b3 in
                                    output.withUnsafeMutableBufferPointer { out in
                                        a10_ultra_m5_host_predictor_i8(
                                            input.baseAddress,
                                            w1.baseAddress, assets.sqlitePredictorW1Scale, assets.sqlitePredictorW1ZeroPoint, b1.baseAddress,
                                            w2.baseAddress, assets.sqlitePredictorW2Scale, assets.sqlitePredictorW2ZeroPoint, b2.baseAddress,
                                            w3.baseAddress, assets.sqlitePredictorW3Scale, assets.sqlitePredictorW3ZeroPoint, b3.baseAddress,
                                            assets.sqlitePredictorInputScale, assets.sqlitePredictorInputZeroPoint,
                                            out.baseAddress
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        guard rc == 0 else { throw A10UltraComputeError.unavailable("A10 Ultra Ω SQLite M4 INT8 Predictor Native 错误：\(rc)") }
        return output
    }

    private func generateClause(
        domain: String,
        state: String,
        question: String,
        assets: A10UltraM5Assets,
        maxNew: Int = 12
    ) throws -> [String] {
        let names = ["BOS", domain, state, question, "SEP"]
        let prefix = names.compactMap { assets.ids[$0] }
        guard prefix.count == names.count else { return ["S_UNKNOWN", "T_COLLECT_MORE", "A_NEED_MORE", "A_READ_ONLY", "EOS"] }
        var context = [Float](repeating: 0, count: 69)
        for id in Set(prefix) { context[id] = 1 }
        var hidden = [Float](repeating: 0, count: 96)
        for h in 0..<96 {
            var sum: Float = 0
            for t in 0..<69 where context[t] != 0 { sum += context[t] * assets.C[t * 96 + h] }
            hidden[h] = Float(Foundation.tanh(Double(sum)))
        }
        var logits = [Float](repeating: 0, count: 69)
        for token in prefix { try rnnStep(token: token, hidden: &hidden, logits: &logits, assets: assets) }
        var output: [String] = []
        for _ in 0..<maxNew {
            guard let token = logits.indices.max(by: { logits[$0] < logits[$1] }) else { break }
            let name = assets.vocab[token]
            output.append(name)
            if name == "EOS" { break }
            try rnnStep(token: token, hidden: &hidden, logits: &logits, assets: assets)
        }
        return output
    }

    private func rnnStep(token: Int, hidden: inout [Float], logits: inout [Float], assets: A10UltraM5Assets) throws {
        let rc = assets.E.withUnsafeBufferPointer { e in
            assets.W.withUnsafeBufferPointer { w in
                assets.bh.withUnsafeBufferPointer { bh in
                    assets.O.withUnsafeBufferPointer { o in
                        assets.bo.withUnsafeBufferPointer { bo in
                            hidden.withUnsafeMutableBufferPointer { h in
                                logits.withUnsafeMutableBufferPointer { l in
                                    a10_ultra_m5_rnn_step_f32(
                                        e.baseAddress, w.baseAddress, bh.baseAddress, o.baseAddress, bo.baseAddress,
                                        Int32(token), h.baseAddress, l.baseAddress
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        guard rc == 0 else { throw A10UltraComputeError.unavailable("A10 Ultra Ω M5 RNN Native 错误：\(rc)") }
    }

    private static func streamChunks(_ text: String, targetCharacters: Int) -> [String] {
        guard !text.isEmpty else { return [] }
        var chunks: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if current.count >= targetCharacters {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}

/// Converts existing LingCore context into the M4 synthetic feature space without exposing
/// message plaintext. This is intentionally a proxy adapter; it is logged as such and is not
/// presented as a calibrated real-world sensor mapping.
enum A10UltraM5FeatureAdapter {
    static let version = "VEILLINK_M4_PROXY_V1"

    static func features(from context: AgentLocalContext?) -> [Float]? {
        guard let context else { return nil }
        var u = [Float](repeating: 0.5, count: 32)
        let health = Float(context.bluetooth.weakestHealth ?? 100) / 100
        u[0] = clamp01(health)
        u[1] = clamp01(1 - health)
        u[2] = clamp01(Float(context.bluetooth.recoveringPeers) / 4)
        u[3] = clamp01(Float(context.bluetooth.recoveringPeers) / Float(max(1, context.bluetooth.trackedPeers)))
        u[4] = clamp01(Float(context.bluetooth.pendingBytes) / Float(512 * 1_024))
        u[5] = clamp01(Float(context.bluetooth.pendingBytes) / Float(128 * 1_024))
        u[6] = clamp01(Float(context.bluetooth.pendingBytes) / Float(2 * 1_024 * 1_024))
        u[7] = u[5]
        u[8] = 0.75
        u[9] = 0.25
        u[10] = 1
        u[11] = 0
        u[12] = context.databaseIntegrity == "异常" ? 1 : 0
        u[13] = context.databaseIntegrity == "正常" ? 1 : (context.databaseIntegrity == "异常" ? 0 : 0.5)
        u[14] = context.a9HealthScore < 60 ? 0.75 : 0.25
        u[15] = context.a9HealthScore < 50 ? 0.75 : 0.25
        u[16] = clamp01(1 - u[4])
        u[17] = context.a9Mode.contains("CONSTRAINED") ? 0.75 : 0.35
        u[18] = context.maleCNSState.contains("失败") ? 0.9 : 0.35
        u[19] = context.game == nil ? 0.1 : 0.65
        return u.map { $0 * 2 - 1 }
    }

    static func features(
        input: VeilA9Input,
        foregroundActive: Bool,
        batteryLevel: Float,
        agentGenerating: Bool,
        gameActive: Bool
    ) -> [Float] {
        var u = [Float](repeating: 0.5, count: 32)
        let health = Float(input.minimumLinkHealth ?? (input.connectedPeerCount > 0 ? 85 : 100)) / 100
        u[0] = clamp01(health)
        u[1] = clamp01(1 - health)
        u[2] = clamp01(Float(input.maximumReconnectAttempt) / 6)
        u[3] = clamp01(Float(input.recoveringPeerCount) / Float(max(1, input.trackedPeerCount)))
        u[4] = clamp01(Float(input.pendingBytes) / Float(512 * 1_024))
        u[5] = clamp01(Float(input.controlPendingPackets) / 32)
        u[6] = clamp01(Float(input.pendingBytes) / Float(2 * 1_024 * 1_024))
        u[7] = clamp01(Float(input.maximumStallMilliseconds) / 5_000)
        u[8] = batteryLevel >= 0 ? clamp01(batteryLevel) : 0.75
        u[9] = clamp01(Float(input.thermalLevel.rawValue) / 3)
        u[10] = foregroundActive ? 1 : 0
        u[11] = foregroundActive ? 0 : 1
        u[12] = input.databaseIntegrity == .failed ? 1 : 0
        switch input.databaseIntegrity {
        case .ok: u[13] = 1
        case .unchecked: u[13] = 0.5
        case .failed: u[13] = 0
        }
        u[14] = max(u[9], agentGenerating ? 0.7 : 0.25)
        u[15] = input.lowPowerMode ? 0.75 : 0.25
        u[16] = clamp01(1 - max(u[4], u[9]))
        u[17] = max(agentGenerating ? 0.7 : 0.2, gameActive ? 0.6 : 0.2)
        u[18] = input.agentHasFailure ? 1 : (input.agentCooling ? 0.7 : (agentGenerating ? 0.6 : 0.2))
        u[19] = gameActive ? 0.7 : 0.1
        return u.map { $0 * 2 - 1 }
    }

    private static func clamp01(_ value: Float) -> Float { min(1, max(0, value)) }
}
