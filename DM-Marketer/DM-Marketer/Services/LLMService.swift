import Foundation
import FoundationModels

// MARK: - Protocol

/// Backends that can write a reply. The app ships with AppleModelService; MockLLMService is for previews.
protocol LLMService: AnyObject {
    var isModelLoaded: Bool { get }
    /// Token window shared by instructions, prompt and output — used by ChatViewModel for history truncation.
    var contextWindowSize: Int { get }
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

    var errorDescription: String? {
        switch self {
        case .noModelLoaded:           return "Apple Intelligence isn't available right now."
        case .generationFailed(let m): return "Generation failed: \(m)"
        }
    }
}

// MARK: - Mock (previews)

final class MockLLMService: LLMService {
    var isModelLoaded: Bool = false
    var contextWindowSize: Int = 2048

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

// MARK: - Apple Intelligence (on-device Foundation Models)

final class AppleModelService: LLMService {
    var isModelLoaded: Bool { SystemLanguageModel.default.availability == .available }
    /// Apple's on-device model shares 4,096 tokens across instructions, prompt and output.
    let contextWindowSize = 4096

    func generate(systemPrompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard SystemLanguageModel.default.availability == .available else {
                    continuation.finish(throwing: LLMError.noModelLoaded)
                    return
                }
                do {
                    let session = LanguageModelSession(instructions: systemPrompt)
                    var sent = 0
                    for try await snapshot in session.streamResponse(to: Self.prompt(from: history)) {
                        let text = snapshot.content
                        // Snapshots are cumulative; the stream carries only the new part.
                        if text.count > sent {
                            continuation.yield(String(text.dropFirst(sent)))
                            sent = text.count
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: LLMError.generationFailed(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The model takes one prompt, so earlier turns are folded into it.
    private static func prompt(from history: [ChatMessage]) -> String {
        guard let last = history.last else { return "" }
        let earlier = history.dropLast()
        guard !earlier.isEmpty else { return last.content }
        let transcript = earlier
            .map { ($0.role == .user ? "User: " : "You: ") + $0.content }
            .joined(separator: "\n")
        return "Conversation so far:\n\(transcript)\n\nUser: \(last.content)"
    }
}
