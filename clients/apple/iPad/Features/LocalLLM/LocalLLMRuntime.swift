import Foundation

protocol LocalLLMRuntime {
    func generate(
        model: LocalLLMModelRecord,
        request: LocalLLMGenerationRequest
    ) async throws -> LocalLLMGenerationResult

    func unload() async
}

enum LocalLLMRuntimeError: LocalizedError {
    case modelFileMissing
    case runtimeUnavailable
    case modelLoadFailed(String)
    case contextLoadFailed
    case promptTooLong(required: Int, available: Int)
    case tokenizationFailed
    case decodeFailed
    case samplerUnavailable

    var errorDescription: String? {
        switch self {
        case .modelFileMissing:
            return "The active model file is missing from local storage."
        case .runtimeUnavailable:
            return "The llama.cpp runtime library is not linked."
        case .modelLoadFailed(let path):
            return "The llama.cpp runtime could not load the model at \(path)."
        case .contextLoadFailed:
            return "The llama.cpp runtime could not create an inference context."
        case .promptTooLong(let required, let available):
            return "The prompt needs \(required) tokens, but the runtime context supports \(available)."
        case .tokenizationFailed:
            return "The llama.cpp runtime could not tokenize the prompt."
        case .decodeFailed:
            return "The llama.cpp runtime failed during decoding."
        case .samplerUnavailable:
            return "The llama.cpp sampler could not be initialized."
        }
    }
}
