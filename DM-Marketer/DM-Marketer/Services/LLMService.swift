import Foundation

// MARK: - Protocol

/// All LLM backends conform to this. The app ships with MockLLMService.
/// Swap in LlamaCppService (or MLXService) once you add the Swift package.
protocol LLMService: AnyObject {
    var isModelLoaded: Bool { get }
    func loadModel(at url: URL) async throws
    func unloadModel()
    /// Returns an async stream of token strings. Accumulate them for the full response.
    func generate(systemPrompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}

struct ChatMessage {
    let role: MessageRole
    let content: String
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case noModelLoaded
    case generationFailed(String)
    case modelFileNotFound

    var errorDescription: String? {
        switch self {
        case .noModelLoaded:       return "No model loaded. Download a model in the Models tab."
        case .generationFailed(let m): return "Generation failed: \(m)"
        case .modelFileNotFound:   return "Model file not found. Try re-downloading."
        }
    }
}

// MARK: - Mock (ships by default, no llama.cpp needed)

final class MockLLMService: LLMService {
    var isModelLoaded: Bool = false

    func loadModel(at url: URL) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func unloadModel() {}

    func generate(systemPrompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let response = Self.buildMockResponse(systemPrompt: systemPrompt, lastUserMessage: history.last?.content ?? "")
        return AsyncThrowingStream { continuation in
            Task {
                let words = response.components(separatedBy: " ")
                for (i, word) in words.enumerated() {
                    try await Task.sleep(for: .milliseconds(55))
                    continuation.yield(word + (i < words.count - 1 ? " " : ""))
                }
                continuation.finish()
            }
        }
    }

    private static func buildMockResponse(systemPrompt: String, lastUserMessage: String) -> String {
        return "This is a placeholder. Install a local model in the Models tab to generate real AI-written DMs."
    }

}

// MARK: - LlamaCppService stub (ready for real integration)

/// To activate: add llama.cpp as a Swift Package, then implement the TODOs below.
/// Package URL: https://github.com/ggerganov/llama.cpp (has a Package.swift)
final class LlamaCppService: LLMService {
    var isModelLoaded: Bool = false

    func loadModel(at url: URL) async throws {
        // TODO: llama_backend_init()
        // TODO: llama_model_load(url.path, params)
        // TODO: llama_new_context_with_model(model, ctx_params)
        isModelLoaded = true
    }

    func unloadModel() {
        // TODO: llama_free(ctx); llama_free_model(model); llama_backend_free()
        isModelLoaded = false
    }

    func generate(systemPrompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMError.generationFailed("llama.cpp not yet integrated"))
        }
    }
}
