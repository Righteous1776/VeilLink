import Foundation

#if canImport(llama)
import llama

struct LlamaGenerationStats: Equatable, Sendable {
    let text: String
    let emittedChunkCount: Int
    let generatedTokenCount: Int
    let promptTokenCount: Int
    let firstVisibleTokenMilliseconds: Int?
    let totalMilliseconds: Int
    let generatedTokensPerSecond: Double
    let usedModelChatTemplate: Bool
}

enum LlamaEngineError: LocalizedError {
    case modelLoadFailed
    case contextCreationFailed
    case tokenizerFailed
    case contextOverflow(required: Int, capacity: Int)
    case decodeFailed(Int32)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed: return "llama.cpp 无法加载本地 GGUF。"
        case .contextCreationFailed: return "llama.cpp 无法创建推理上下文。"
        case .tokenizerFailed: return "本地模型分词失败。"
        case .contextOverflow: return "当前本地对话超过设备上下文预算。"
        case .decodeFailed: return "llama.cpp 本地推理失败。"
        case .unavailable: return "llama.cpp 本地运行时不可用。"
        }
    }
}

actor LlamaInferenceEngine {
    private let configuration: LlamaRuntimeConfiguration
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    private var sampler: UnsafeMutablePointer<llama_sampler>?
    private var batch: llama_batch?
    private var backendInitialized = false
    private var invalidUTF8: [CChar] = []
    private let cancellationGate: LlamaCancellationGate

    init(
        configuration: LlamaRuntimeConfiguration,
        cancellationGate: LlamaCancellationGate = LlamaCancellationGate()
    ) {
        self.configuration = configuration
        self.cancellationGate = cancellationGate
    }

    func load(modelURL: URL) throws {
        guard model == nil, context == nil else { return }
        llama_backend_init()
        backendInitialized = true

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = configuration.gpuLayers
        modelParams.check_tensors = true

        guard let loadedModel = llama_model_load_from_file(modelURL.path, modelParams) else {
            shutdownInternal()
            throw LlamaEngineError.modelLoadFailed
        }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(configuration.contextTokens)
        contextParams.n_batch = UInt32(configuration.batchTokens)
        contextParams.n_ubatch = UInt32(configuration.batchTokens)
        contextParams.n_threads = Int32(configuration.threads)
        contextParams.n_threads_batch = Int32(configuration.threads)
        contextParams.no_perf = false

        guard let loadedContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            shutdownInternal()
            throw LlamaEngineError.contextCreationFailed
        }

        let samplerParams = llama_sampler_chain_default_params()
        guard let samplerChain = llama_sampler_chain_init(samplerParams) else {
            llama_free(loadedContext)
            llama_model_free(loadedModel)
            shutdownInternal()
            throw LlamaEngineError.contextCreationFailed
        }
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_k(configuration.topK))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_p(configuration.topP, 1))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_min_p(configuration.minP, 1))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_temp(configuration.temperature))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_dist(UInt32.max))

        model = loadedModel
        context = loadedContext
        vocab = llama_model_get_vocab(loadedModel)
        sampler = samplerChain
        batch = llama_batch_init(Int32(configuration.batchTokens), 0, 1)
    }

    func generate(
        prompt fallbackPrompt: String,
        chatMessages: [QwenChatMessage]? = nil,
        maxNewTokens: Int,
        onPiece: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> LlamaGenerationStats {
        guard let model, let context, let vocab, let sampler, var workingBatch = batch else {
            throw LlamaEngineError.unavailable
        }

        let cancellationGeneration = cancellationGate.snapshot()
        await Task.yield()
        try Task.checkCancellation()
        guard cancellationGate.isCurrent(cancellationGeneration) else { throw CancellationError() }
        llama_sampler_reset(sampler)
        llama_memory_clear(llama_get_memory(context), true)
        invalidUTF8.removeAll(keepingCapacity: true)

        let rendered = chatMessages.flatMap { applyModelChatTemplate($0, model: model) }
        let prompt = rendered ?? fallbackPrompt
        let usedModelChatTemplate = rendered != nil
        let tokens = try tokenize(prompt, vocab: vocab)
        let safeMaxNew = max(1, maxNewTokens)
        let capacity = Int(llama_n_ctx(context))
        let required = tokens.count + safeMaxNew + 1
        guard required <= capacity else {
            throw LlamaEngineError.contextOverflow(required: required, capacity: capacity)
        }

        let started = DispatchTime.now().uptimeNanoseconds
        var cursor = 0
        while cursor < tokens.count {
            await Task.yield()
            try Task.checkCancellation()
            guard cancellationGate.isCurrent(cancellationGeneration) else { throw CancellationError() }
            clearBatch(&workingBatch)
            let end = min(tokens.count, cursor + configuration.batchTokens)
            for index in cursor..<end {
                add(
                    token: tokens[index],
                    position: Int32(index),
                    logits: index == tokens.count - 1,
                    to: &workingBatch
                )
            }
            let code = llama_decode(context, workingBatch)
            guard code == 0 else { throw LlamaEngineError.decodeFailed(code) }
            cursor = end
        }

        var filter = QwenVisibleOutputFilter()
        var output = ""
        var emittedChunks = 0
        var generatedTokens = 0
        var firstVisibleMilliseconds: Int?

        for offset in 0..<safeMaxNew {
            await Task.yield()
            try Task.checkCancellation()
            guard cancellationGate.isCurrent(cancellationGeneration) else { throw CancellationError() }
            let token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }

            let rawPiece = tokenToPiece(token, vocab: vocab)
            let visible = filter.consume(rawPiece)
            if !visible.isEmpty {
                if firstVisibleMilliseconds == nil {
                    firstVisibleMilliseconds = milliseconds(since: started)
                }
                output += visible
                emittedChunks += 1
                await onPiece(visible)
            }
            generatedTokens += 1

            clearBatch(&workingBatch)
            add(
                token: token,
                position: Int32(tokens.count + offset),
                logits: true,
                to: &workingBatch
            )
            let code = llama_decode(context, workingBatch)
            guard code == 0 else { throw LlamaEngineError.decodeFailed(code) }
        }

        await Task.yield()
        try Task.checkCancellation()
        guard cancellationGate.isCurrent(cancellationGeneration) else { throw CancellationError() }

        let tail = filter.finish()
        if !tail.isEmpty {
            if firstVisibleMilliseconds == nil { firstVisibleMilliseconds = milliseconds(since: started) }
            output += tail
            emittedChunks += 1
            await onPiece(tail)
        }

        batch = workingBatch
        let totalMilliseconds = max(1, milliseconds(since: started))
        let seconds = Double(totalMilliseconds) / 1_000.0
        let rate = Double(generatedTokens) / max(0.001, seconds)
        return LlamaGenerationStats(
            text: output,
            emittedChunkCount: emittedChunks,
            generatedTokenCount: generatedTokens,
            promptTokenCount: tokens.count,
            firstVisibleTokenMilliseconds: firstVisibleMilliseconds,
            totalMilliseconds: totalMilliseconds,
            generatedTokensPerSecond: rate,
            usedModelChatTemplate: usedModelChatTemplate
        )
    }

    func trim() {
        guard let context else { return }
        llama_memory_clear(llama_get_memory(context), true)
        llama_sampler_reset(sampler)
        invalidUTF8.removeAll(keepingCapacity: false)
    }

    func shutdown() {
        shutdownInternal()
    }

    private func shutdownInternal() {
        if let sampler {
            llama_sampler_free(sampler)
            self.sampler = nil
        }
        if let batch {
            llama_batch_free(batch)
            self.batch = nil
        }
        if let context {
            llama_free(context)
            self.context = nil
        }
        if let model {
            llama_model_free(model)
            self.model = nil
        }
        vocab = nil
        invalidUTF8.removeAll(keepingCapacity: false)
        if backendInitialized {
            llama_backend_free()
            backendInitialized = false
        }
    }

    private func tokenize(_ text: String, vocab: OpaquePointer) throws -> [llama_token] {
        let byteCount = Int32(text.utf8.count)
        var storage = [llama_token](repeating: 0, count: max(32, Int(byteCount) + 16))
        var count = storage.withUnsafeMutableBufferPointer { buffer in
            llama_tokenize(vocab, text, byteCount, buffer.baseAddress, Int32(buffer.count), false, true)
        }
        if count < 0 {
            storage = [llama_token](repeating: 0, count: Int(-count))
            count = storage.withUnsafeMutableBufferPointer { buffer in
                llama_tokenize(vocab, text, byteCount, buffer.baseAddress, Int32(buffer.count), false, true)
            }
        }
        guard count >= 0 else { throw LlamaEngineError.tokenizerFailed }
        return Array(storage.prefix(Int(count)))
    }

    private func applyModelChatTemplate(_ messages: [QwenChatMessage], model: OpaquePointer) -> String? {
        guard !messages.isEmpty,
              let template = llama_model_chat_template(model, nil) else { return nil }

        let roleBuffers = messages.map { allocateCString($0.role) }
        let contentBuffers = messages.map { allocateCString($0.content) }
        defer {
            roleBuffers.forEach { $0.deallocate() }
            contentBuffers.forEach { $0.deallocate() }
        }

        var cMessages = zip(roleBuffers, contentBuffers).map { role, content in
            llama_chat_message(role: UnsafePointer(role), content: UnsafePointer(content))
        }

        let required = cMessages.withUnsafeMutableBufferPointer { buffer in
            llama_chat_apply_template(template, buffer.baseAddress, buffer.count, true, nil, 0)
        }
        guard required > 0 else { return nil }

        var output = [CChar](repeating: 0, count: Int(required) + 1)
        let written = cMessages.withUnsafeMutableBufferPointer { messagesBuffer in
            output.withUnsafeMutableBufferPointer { outputBuffer in
                llama_chat_apply_template(
                    template,
                    messagesBuffer.baseAddress,
                    messagesBuffer.count,
                    true,
                    outputBuffer.baseAddress,
                    Int32(outputBuffer.count)
                )
            }
        }
        guard written > 0, written <= required else { return nil }
        let bytes = output.prefix(Int(written)).map { UInt8(bitPattern: $0) }
        return String(bytes: bytes, encoding: .utf8)
    }

    private func allocateCString(_ text: String) -> UnsafeMutablePointer<CChar> {
        let bytes = Array(text.utf8CString)
        let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count)
        bytes.withUnsafeBufferPointer { buffer in
            if let baseAddress = buffer.baseAddress {
                pointer.initialize(from: baseAddress, count: buffer.count)
            }
        }
        return pointer
    }

    private func clearBatch(_ batch: inout llama_batch) {
        batch.n_tokens = 0
    }

    private func add(token: llama_token, position: llama_pos, logits: Bool, to batch: inout llama_batch) {
        let index = Int(batch.n_tokens)
        batch.token[index] = token
        batch.pos[index] = position
        batch.n_seq_id[index] = 1
        batch.seq_id[index]![0] = 0
        batch.logits[index] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    private func tokenToPiece(_ token: llama_token, vocab: OpaquePointer) -> String {
        var small = [CChar](repeating: 0, count: 16)
        var count = small.withUnsafeMutableBufferPointer { buffer in
            llama_token_to_piece(vocab, token, buffer.baseAddress, Int32(buffer.count), 0, false)
        }
        var bytes: [CChar]
        if count < 0 {
            bytes = [CChar](repeating: 0, count: Int(-count))
            count = bytes.withUnsafeMutableBufferPointer { buffer in
                llama_token_to_piece(vocab, token, buffer.baseAddress, Int32(buffer.count), 0, false)
            }
            guard count >= 0 else { return "" }
            bytes = Array(bytes.prefix(Int(count)))
        } else {
            bytes = Array(small.prefix(Int(count)))
        }

        invalidUTF8.append(contentsOf: bytes)
        let data = Data(invalidUTF8.map { UInt8(bitPattern: $0) })
        if let string = String(data: data, encoding: .utf8) {
            invalidUTF8.removeAll(keepingCapacity: true)
            return string
        }
        if invalidUTF8.count > 12 {
            invalidUTF8.removeAll(keepingCapacity: true)
        }
        return ""
    }

    private func milliseconds(since start: UInt64) -> Int {
        Int((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
    }
}
#endif
