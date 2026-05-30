import Foundation

#if canImport(llama)
import llama
#endif

actor LlamaCppRuntimeAdapter: LocalLLMRuntime {
    private var session: LlamaCppSession?

    func generate(
        model: LocalLLMModelRecord,
        request: LocalLLMGenerationRequest
    ) async throws -> LocalLLMGenerationResult {
        guard let localPath = model.localPath,
              FileManager.default.fileExists(atPath: localPath)
        else {
            throw LocalLLMRuntimeError.modelFileMissing
        }

        let activeSession = try loadSession(modelID: model.id, localPath: localPath)
        let prompt = Self.prompt(instructions: request.instructions, input: request.input)
        let maxOutputTokens = max(1, min(request.maxOutputTokens ?? 128, 512))
        let generation = try activeSession.generate(
            prompt: prompt,
            maxOutputTokens: maxOutputTokens,
            temperature: request.temperature,
            topP: request.topP
        )

        return LocalLLMGenerationResult(
            modelID: model.id,
            outputText: generation.text.trimmingCharacters(in: .whitespacesAndNewlines),
            inputTokens: generation.inputTokens,
            outputTokens: generation.outputTokens
        )
    }

    func unload() async {
        session = nil
    }

    private func loadSession(modelID: String, localPath: String) throws -> LlamaCppSession {
        if let session,
           session.modelID == modelID,
           session.localPath == localPath {
            return session
        }

        session = nil
        let loadedSession = try LlamaCppSession(modelID: modelID, localPath: localPath)
        session = loadedSession
        return loadedSession
    }

    private static func prompt(instructions: String?, input: String) -> String {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let instructions = instructions?.trimmingCharacters(in: .whitespacesAndNewlines),
              instructions.isEmpty == false
        else {
            return "User:\n\(trimmedInput)\n\nAssistant:\n"
        }

        return "System:\n\(instructions)\n\nUser:\n\(trimmedInput)\n\nAssistant:\n"
    }
}

struct LlamaCppGeneration {
    var text: String
    var inputTokens: Int
    var outputTokens: Int
}

#if canImport(llama)
private func llamaBatchClear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

private func llamaBatchAdd(
    _ batch: inout llama_batch,
    _ token: llama_token,
    _ position: llama_pos,
    _ sequenceIDs: [llama_seq_id],
    _ logits: Bool
) {
    let index = Int(batch.n_tokens)
    batch.token[index] = token
    batch.pos[index] = position
    batch.n_seq_id[index] = Int32(sequenceIDs.count)

    for sequenceIndex in 0..<sequenceIDs.count {
        batch.seq_id[index]![sequenceIndex] = sequenceIDs[sequenceIndex]
    }

    batch.logits[index] = logits ? 1 : 0
    batch.n_tokens += 1
}

private final class LlamaCppSession {
    let modelID: String
    let localPath: String

    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private var batch: llama_batch
    private var pendingUTF8Bytes: [CChar] = []

    init(modelID: String, localPath: String) throws {
        self.modelID = modelID
        self.localPath = localPath

        llama_backend_init()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 99

        #if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
        #endif

        guard let loadedModel = llama_model_load_from_file(localPath, modelParams) else {
            llama_backend_free()
            throw LocalLLMRuntimeError.modelLoadFailed(localPath)
        }

        let threadCount = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 2048
        contextParams.n_batch = 512
        contextParams.n_threads = Int32(threadCount)
        contextParams.n_threads_batch = Int32(threadCount)

        guard let loadedContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            llama_backend_free()
            throw LocalLLMRuntimeError.contextLoadFailed
        }

        model = loadedModel
        context = loadedContext
        vocab = llama_model_get_vocab(loadedModel)
        batch = llama_batch_init(512, 0, 1)
    }

    deinit {
        llama_batch_free(batch)
        llama_free(context)
        llama_model_free(model)
        llama_backend_free()
    }

    func generate(
        prompt: String,
        maxOutputTokens: Int,
        temperature: Double?,
        topP: Double?
    ) throws -> LlamaCppGeneration {
        pendingUTF8Bytes.removeAll()
        llama_kv_self_clear(context)

        let inputTokens = try tokenize(text: prompt, addBOS: true)
        let availableContext = Int(llama_n_ctx(context))
        guard inputTokens.count + maxOutputTokens <= availableContext else {
            throw LocalLLMRuntimeError.promptTooLong(
                required: inputTokens.count + maxOutputTokens,
                available: availableContext
            )
        }

        llamaBatchClear(&batch)
        for tokenIndex in inputTokens.indices {
            llamaBatchAdd(&batch, inputTokens[tokenIndex], Int32(tokenIndex), [0], false)
        }
        batch.logits[Int(batch.n_tokens) - 1] = 1

        guard llama_decode(context, batch) == 0 else {
            throw LocalLLMRuntimeError.decodeFailed
        }

        let sampler = try makeSampler(temperature: temperature, topP: topP)
        defer {
            llama_sampler_free(sampler)
        }

        var generatedText = ""
        var generatedTokenCount = 0
        var currentPosition = Int32(inputTokens.count)

        while generatedTokenCount < maxOutputTokens {
            let token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) {
                generatedText += flushPendingUTF8Bytes()
                break
            }

            llama_sampler_accept(sampler, token)
            generatedText += piece(for: token)

            llamaBatchClear(&batch)
            llamaBatchAdd(&batch, token, currentPosition, [0], true)

            guard llama_decode(context, batch) == 0 else {
                throw LocalLLMRuntimeError.decodeFailed
            }

            generatedTokenCount += 1
            currentPosition += 1
        }

        generatedText += flushPendingUTF8Bytes()

        return LlamaCppGeneration(
            text: generatedText,
            inputTokens: inputTokens.count,
            outputTokens: generatedTokenCount
        )
    }

    private func makeSampler(temperature: Double?, topP: Double?) throws -> UnsafeMutablePointer<llama_sampler> {
        let samplerParams = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(samplerParams) else {
            throw LocalLLMRuntimeError.samplerUnavailable
        }

        let resolvedTemperature = Float(temperature ?? 0.7)
        if resolvedTemperature <= 0 {
            llama_sampler_chain_add(sampler, llama_sampler_init_greedy())
        } else {
            llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
            llama_sampler_chain_add(sampler, llama_sampler_init_top_p(Float(topP ?? 0.9), 1))
            llama_sampler_chain_add(sampler, llama_sampler_init_temp(resolvedTemperature))
            llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 1...UInt32.max)))
        }

        return sampler
    }

    private func tokenize(text: String, addBOS: Bool) throws -> [llama_token] {
        let utf8Count = text.utf8.count
        let tokenCapacity = max(8, utf8Count + (addBOS ? 1 : 0) + 1)
        let tokenPointer = UnsafeMutablePointer<llama_token>.allocate(capacity: tokenCapacity)
        defer {
            tokenPointer.deallocate()
        }

        let tokenCount = llama_tokenize(
            vocab,
            text,
            Int32(utf8Count),
            tokenPointer,
            Int32(tokenCapacity),
            addBOS,
            false
        )
        guard tokenCount >= 0 else {
            throw LocalLLMRuntimeError.tokenizationFailed
        }

        return (0..<Int(tokenCount)).map { tokenPointer[$0] }
    }

    private func piece(for token: llama_token) -> String {
        let tokenBytes = tokenToBytes(token)
        pendingUTF8Bytes.append(contentsOf: tokenBytes)

        if let string = String(validatingUTF8: pendingUTF8Bytes + [0]) {
            pendingUTF8Bytes.removeAll()
            return string
        }

        for suffixLength in 1..<pendingUTF8Bytes.count {
            let suffix = Array(pendingUTF8Bytes.suffix(suffixLength)) + [0]
            if String(validatingUTF8: suffix) != nil {
                let string = String(cString: pendingUTF8Bytes + [0])
                pendingUTF8Bytes.removeAll()
                return string
            }
        }

        return ""
    }

    private func flushPendingUTF8Bytes() -> String {
        guard pendingUTF8Bytes.isEmpty == false else {
            return ""
        }

        let string = String(cString: pendingUTF8Bytes + [0])
        pendingUTF8Bytes.removeAll()
        return string
    }

    private func tokenToBytes(_ token: llama_token) -> [CChar] {
        let initialCapacity = 16
        let initialPointer = UnsafeMutablePointer<CChar>.allocate(capacity: initialCapacity)
        initialPointer.initialize(repeating: 0, count: initialCapacity)
        defer {
            initialPointer.deallocate()
        }

        let byteCount = llama_token_to_piece(vocab, token, initialPointer, Int32(initialCapacity), 0, false)
        if byteCount >= 0 {
            return Array(UnsafeBufferPointer(start: initialPointer, count: Int(byteCount)))
        }

        let requiredCapacity = Int(-byteCount)
        let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: requiredCapacity)
        pointer.initialize(repeating: 0, count: requiredCapacity)
        defer {
            pointer.deallocate()
        }

        let resolvedByteCount = llama_token_to_piece(vocab, token, pointer, Int32(requiredCapacity), 0, false)
        guard resolvedByteCount > 0 else {
            return []
        }

        return Array(UnsafeBufferPointer(start: pointer, count: Int(resolvedByteCount)))
    }
}
#else
private final class LlamaCppSession {
    let modelID: String
    let localPath: String

    init(modelID: String, localPath: String) throws {
        self.modelID = modelID
        self.localPath = localPath
        throw LocalLLMRuntimeError.runtimeUnavailable
    }

    func generate(
        prompt: String,
        maxOutputTokens: Int,
        temperature: Double?,
        topP: Double?
    ) throws -> LlamaCppGeneration {
        throw LocalLLMRuntimeError.runtimeUnavailable
    }
}
#endif
