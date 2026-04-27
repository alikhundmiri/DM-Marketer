import Foundation

// MARK: - Protocol

/// All LLM backends conform to this. The app ships with MockLLMService.
/// Swap in LlamaCppService (or MLXService) once you add the Swift package.
protocol LLMService: AnyObject {
    var isModelLoaded: Bool { get }
    /// The n_ctx value that was passed to loadModel — used by ChatViewModel for history truncation.
    var contextWindowSize: Int { get }
    func loadModel(at url: URL, nCtx: Int) async throws
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
    var contextWindowSize: Int = 2048

    func loadModel(at url: URL, nCtx: Int) async throws {
        try await Task.sleep(for: .milliseconds(300))
        contextWindowSize = nCtx
        isModelLoaded = true
    }

    func unloadModel() {
        isModelLoaded = false
    }

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
        let msg = lastUserMessage.lowercased()

        let isTwitter  = systemPrompt.contains("Twitter/X DM")
        let isLinkedIn = systemPrompt.contains("LinkedIn DM")
        let isReddit   = systemPrompt.contains("Reddit DM")

        let isShorter      = msg.contains("shorter")
        let isCasual       = msg.contains("casual")
        let isProfessional = msg.contains("professional")
        let isQuestion     = msg.contains("question")
        let isLessSalesy   = msg.contains("salesy") || msg.contains("tone down")
        let isEmpathetic   = msg.contains("empath")
        let isVariation    = msg.contains("different") || msg.contains("variation") || msg.contains("fresh")

        if isTwitter {
            if isShorter       { return "Saw your post — been in that exact spot. Found something that actually helped me ship instead of spin." }
            if isCasual        { return "ok your post literally just described my last 3 months lol. found something that helped, worth 5 mins?" }
            if isProfessional  { return "Your experience aligns closely with a problem I've spent the last year solving. Happy to share what worked." }
            if isQuestion      { return "Your post hit close to home — I've been through the same thing. What's been the hardest part of it for you so far?" }
            if isLessSalesy    { return "That feeling you described is real. I've been sitting with a similar thing and the thing that helped wasn't obvious at all." }
            if isEmpathetic    { return "That post sounds exhausting — I've been there. The worst part is not knowing if you're even close. Happy to share what finally clicked." }
            if isVariation     { return "Something in your post made me stop scrolling. I've had almost that exact experience and there's one thing I wish someone had told me earlier." }
            return "Your post is basically my diary from 6 months ago. The thing that finally moved the needle — happy to share if you're curious."
        }

        if isLinkedIn {
            if isShorter       { return "Your point landed with me — I've been working on something that directly addresses this. Happy to share if it's useful." }
            if isCasual        { return "Honestly your post made me nod the whole way through. I've been quietly building something for exactly this — would love your take." }
            if isProfessional  { return "Your post articulates a challenge I've spent the past year working to solve. I've developed something that may be directly relevant — happy to share more." }
            if isQuestion      { return "Your perspective really clicked with something I've been building. I'm curious — how are you currently handling the part where it all breaks down?" }
            if isLessSalesy    { return "What you described is something a lot of people are quietly struggling with. I've been thinking about this too — might be worth a quick conversation." }
            if isEmpathetic    { return "That sounds genuinely frustrating — putting in the work and not seeing results is demoralizing. I understand that well. Happy to share what shifted things for me." }
            if isVariation     { return "I almost scrolled past your post but the way you framed it made me pause. I've been in that exact situation and found a way through it that wasn't obvious." }
            return "Your post described something I've spent the past year quietly working to solve. I built something that addresses it directly — happy to share if it fits what you're dealing with."
        }

        if isReddit {
            if isShorter       { return "Dealt with the same thing — found something that actually helped. DM me if you want the details." }
            if isCasual        { return "wait your post is basically my experience from last year. ended up finding something that helped — kinda weird how well it worked tbh" }
            if isProfessional  { return "Your comment reflects a challenge I tackled directly. I developed something that addresses it — happy to share if it seems relevant." }
            if isQuestion      { return "Your comment is almost word-for-word what I was saying a year ago. Eventually found something that helped — what have you tried so far?" }
            if isLessSalesy    { return "The frustration you're describing is real. I spent a long time in that headspace before something finally clicked — happy to talk about it if useful." }
            if isEmpathetic    { return "Genuinely, that sounds rough. Putting in the work and seeing nothing is the most demoralizing phase. Been there — eventually found something that helped." }
            if isVariation     { return "I've been in this sub a while and your post is one of the more honest takes I've seen on this. I figured out something that helped with my version of it." }
            return "Dealt with exactly this last year. Tried a bunch of things, most didn't work. Eventually found something that actually did — happy to share if it sounds useful."
        }

        // Generic / other platform
        if isShorter  { return "Your message hit close to home — I've been working on something that directly addresses this." }
        if isVariation { return "Something you said made me think about this differently. I've been building something that tackles this from a completely different angle." }
        return "What you described resonates with a problem I spent the last year solving. Built something that addresses it directly — happy to share more if it seems relevant."
    }

}

// MARK: - LlamaCppService (real on-device inference)
// Requires: llama.xcframework added to DM-Marketer target
// General → Frameworks, Libraries, and Embedded Content → + → llama.xcframework → Embed & Sign

#if canImport(llama)
import llama

/// OpaquePointer is not Sendable, but llama model/context pointers are only ever accessed
/// from within LlamaCppService (single-writer pattern). We wrap them here to silence the
/// Swift 6 Sendable error on Task.detached captures and returns.
private struct LlamaPointers: @unchecked Sendable {
    let model:   OpaquePointer
    let context: OpaquePointer
}

final class LlamaCppService: LLMService {
    // Stored as LlamaPointers (Sendable) so raw OpaquePointers never need to cross
    // actor boundaries — Swift 6 strict concurrency requires Sendable for that.
    private var ptrs: LlamaPointers?
    var isModelLoaded: Bool { ptrs != nil }
    private(set) var contextWindowSize: Int = 2048

    // MARK: Load

    func loadModel(at url: URL, nCtx: Int) async throws {
        let loadedPtrs = try await Task.detached(priority: .userInitiated) { () throws -> LlamaPointers in
            llama_backend_init()
            var mparams = llama_model_default_params()
            // Adaptive GPU offload: iPhone 13 (4 GB) → CPU only to avoid jetsam.
            // 6 GB+ devices (iPhone 14 Pro and newer) can safely offload all layers.
            let ramGB = ProcessInfo.processInfo.physicalMemory / 1_000_000_000
            let gpuLayers: Int32 = ramGB >= 6 ? 99 : 0
            print("[LLM] physicalMemory=\(ramGB) GB → n_gpu_layers=\(gpuLayers), n_ctx=\(nCtx)")
            mparams.n_gpu_layers = gpuLayers
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw LLMError.modelFileNotFound
            }
            guard let m = llama_model_load_from_file(url.path, mparams) else {
                // Give a specific message when the model file is large relative to available RAM.
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                let fileSizeGB = Double(fileSize) / 1_000_000_000
                if fileSizeGB > Double(ramGB) * 0.55 {
                    throw LLMError.generationFailed(
                        "This model (\(String(format: "%.1f", fileSizeGB)) GB) is too large for your device's \(ramGB) GB RAM. " +
                        "Try Qwen 2.5 0.5B or Gemma 3 1B instead."
                    )
                }
                throw LLMError.generationFailed(
                    "Failed to load model — not enough free memory. " +
                    "Try force-quitting other apps, or use a smaller model."
                )
            }
            var cparams = llama_context_default_params()
            cparams.n_ctx = UInt32(nCtx)
            cparams.n_batch = 512
            let threads = Int32(max(1, ProcessInfo.processInfo.processorCount - 1))
            cparams.n_threads = threads
            cparams.n_threads_batch = threads
            guard let c = llama_init_from_model(m, cparams) else {
                llama_model_free(m)
                throw LLMError.generationFailed("Failed to create inference context")
            }
            return LlamaPointers(model: m, context: c)
        }.value
        ptrs = loadedPtrs
        contextWindowSize = nCtx
    }

    // MARK: Unload

    func unloadModel() {
        if let p = ptrs {
            llama_free(p.context)
            llama_model_free(p.model)
        }
        llama_backend_free()
        ptrs = nil
    }

    // MARK: Generate

    func generate(systemPrompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        guard let ptrs else {
            return AsyncThrowingStream { $0.finish(throwing: LLMError.noModelLoaded) }
        }
        return AsyncThrowingStream { continuation in
            // Detached so inference never competes with the main actor for cooperative threads.
            // ptrs is @unchecked Sendable so it crosses the boundary safely.
            Task.detached(priority: .userInitiated) {
                do {
                    try await Self.runInference(
                        ptrs: ptrs,
                        systemPrompt: systemPrompt,
                        history: history,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: Private – Inference

    private static func runInference(
        ptrs: LlamaPointers,
        systemPrompt: String,
        history: [ChatMessage],
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        // Unpack inside the function — no actor boundary crossing needed here.
        let model   = ptrs.model
        let context = ptrs.context
        let vocab = llama_model_get_vocab(model)
        let prompt = try buildPrompt(model: model, systemPrompt: systemPrompt, history: history)

        // Clear the KV cache before each generation.
        // llama_get_memory can return nil on some xcframework builds — guard before passing.
        if let mem = llama_get_memory(context) {
            llama_memory_clear(mem, false)
        }

        let nCtx = Int(llama_n_ctx(context))
        var tokens = [llama_token](repeating: 0, count: nCtx)
        let nPrompt: Int = prompt.withCString { ptr in
            Int(llama_tokenize(vocab, ptr, Int32(prompt.utf8.count), &tokens, Int32(nCtx), true, true))
        }
        guard nPrompt > 0 else {
            throw LLMError.generationFailed("Tokenization produced no tokens")
        }

        // Prefill pass — chunked to respect n_batch=512 limit
        let nBatch = 512
        var prefillStart = 0
        while prefillStart < nPrompt {
            if Task.isCancelled { continuation.finish(); return }
            let chunkSize = min(nBatch, nPrompt - prefillStart)
            var batch = llama_batch_init(Int32(chunkSize), 0, 1)
            defer { llama_batch_free(batch) }
            for i in 0..<chunkSize {
                let gi = prefillStart + i
                batch.token![i]      = tokens[gi]
                batch.pos![i]        = Int32(gi)
                batch.n_seq_id![i]   = 1
                batch.seq_id![i]![0] = 0
                batch.logits![i]     = gi == nPrompt - 1 ? 1 : 0
            }
            batch.n_tokens = Int32(chunkSize)
            guard llama_decode(context, batch) == 0 else {
                throw LLMError.generationFailed("Failed to process prompt")
            }
            prefillStart += chunkSize
        }

        // Sampler chain
        let sparams = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(sparams) else {
            throw LLMError.generationFailed("Failed to create sampler chain")
        }
        defer { llama_sampler_free(sampler) }
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.95, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.75))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED))

        // Generation loop — one token at a time
        var genBatch = llama_batch_init(1, 0, 1)
        defer { llama_batch_free(genBatch) }
        var nCur = nPrompt
        var pieceBuf = [CChar](repeating: 0, count: 256)

        for _ in 0..<512 {
            if Task.isCancelled { break }
            if nCur >= nCtx { break }

            // Yield before the heavy C call so the system can process UI events.
            await Task.yield()
            if Task.isCancelled { break }

            let token = llama_sampler_sample(sampler, context, -1)
            llama_sampler_accept(sampler, token)

            if llama_vocab_is_eog(vocab, token) { break }

            let n = llama_token_to_piece(vocab, token, &pieceBuf, Int32(pieceBuf.count), 0, true)
            if n > 0, let piece = String(bytes: pieceBuf.prefix(Int(n)).map { UInt8(bitPattern: $0) }, encoding: .utf8) {
                continuation.yield(piece)
            }

            genBatch.n_tokens      = 1
            genBatch.token![0]     = token
            genBatch.pos![0]       = Int32(nCur)
            genBatch.n_seq_id![0]  = 1
            genBatch.seq_id![0]![0] = 0
            genBatch.logits![0]    = 1
            nCur += 1

            guard llama_decode(context, genBatch) == 0 else { break }
        }
        continuation.finish()
    }

    // MARK: Private – Prompt building

    private static func buildPrompt(
        model: OpaquePointer,
        systemPrompt: String,
        history: [ChatMessage]
    ) throws -> String {
        let roles: [String]    = ["system"] + history.map { $0.role == .user ? "user" : "assistant" }
        let contents: [String] = [systemPrompt] + history.map { $0.content }

        // strdup keeps each C string alive until we free it at the end of the scope
        let cRoles    = roles.map    { strdup($0) }
        let cContents = contents.map { strdup($0) }
        defer {
            cRoles.forEach    { free($0) }
            cContents.forEach { free($0) }
        }

        let msgs = (0..<roles.count).map { i in
            llama_chat_message(role: cRoles[i], content: cContents[i])
        }

        let tmpl = llama_model_chat_template(model, nil)
        var buf = [CChar](repeating: 0, count: 32_768)
        var len: Int32 = 0
        msgs.withUnsafeBufferPointer { ptr in
            len = llama_chat_apply_template(tmpl, ptr.baseAddress, msgs.count, true, &buf, Int32(buf.count))
        }
        guard len > 0 else {
            throw LLMError.generationFailed("Chat template failed (len=\(len))")
        }
        return String(bytes: buf.prefix(Int(len)).map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
    }
}

#else

// Fallback stub — compiles when llama.xcframework is not yet added to the target.
// To activate: General → Frameworks, Libraries, and Embedded Content → + → llama.xcframework → Embed & Sign
final class LlamaCppService: LLMService {
    var isModelLoaded: Bool = false
    var contextWindowSize: Int = 2048

    func loadModel(at url: URL, nCtx: Int) async throws {
        throw LLMError.generationFailed(
            "Add llama.xcframework to DM-Marketer target: " +
            "General → Frameworks, Libraries, and Embedded Content → + → llama.xcframework → Embed & Sign."
        )
    }

    func unloadModel() { isModelLoaded = false }

    func generate(systemPrompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish(throwing: LLMError.noModelLoaded) }
    }
}

#endif
