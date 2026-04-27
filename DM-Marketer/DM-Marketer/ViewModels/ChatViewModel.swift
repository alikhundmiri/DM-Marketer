import Foundation
import SwiftData
import SwiftUI

@Observable
final class ChatViewModel {
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String?
    var streamingBuffer: String = ""

    private var streamTask: Task<Void, Never>?
    var llmService: any LLMService

    init(llmService: any LLMService) {
        self.llmService = llmService
    }

    // MARK: - Public send (creates a visible user bubble)

    func send(userText: String, chat: Chat, topic: Topic, context: ModelContext) {
        let text = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }

        inputText = ""

        let userMsg = Message(role: .user, content: text)
        userMsg.chat = chat
        chat.messages.append(userMsg)
        context.insert(userMsg)

        let history = chat.sortedMessages.map { ChatMessage(role: $0.role, content: $0.content) }
        let systemPrompt = PromptBuilder.systemPrompt(topic: topic, chat: chat)
        startGeneration(systemPrompt: systemPrompt, history: history, chat: chat, context: context)
    }

    // MARK: - Silent first-DM generation (no visible user bubble)

    /// Called when a chat is opened fresh. Fires the LLM without showing
    /// "Generate a personalized DM for this person." as a user message.
    func autoGenerateFirstDM(chat: Chat, topic: Topic, context: ModelContext) {
        guard chat.messages.isEmpty, !isGenerating, llmService.isModelLoaded else { return }

        let systemPrompt = PromptBuilder.systemPrompt(topic: topic, chat: chat)
        let seed = [ChatMessage(role: .user, content: PromptBuilder.firstUserMessage())]
        startGeneration(systemPrompt: systemPrompt, history: seed, chat: chat, context: context)
    }

    // MARK: - Cancel

    func cancelGeneration() {
        streamTask?.cancel()
        streamTask = nil
        isGenerating = false
        streamingBuffer = ""
    }

    // MARK: - Private

    // Drops the oldest message pairs to keep the prompt within n_ctx - 512 tokens.
    // Estimates 1 token per 4 characters — conservative enough to avoid hard failures.
    private func truncatedHistory(_ history: [ChatMessage], systemPrompt: String) -> [ChatMessage] {
        let nCtx = llmService.contextWindowSize
        let reserved = 512
        let maxInputTokens = nCtx - reserved

        func estimate(_ text: String) -> Int { max(1, text.count / 4) }

        let systemTokens = estimate(systemPrompt)
        var budget = maxInputTokens - systemTokens
        var kept: [ChatMessage] = []
        for msg in history.reversed() {
            let cost = estimate(msg.content)
            guard budget - cost >= 0 else { break }
            kept.append(msg)
            budget -= cost
        }
        return kept.reversed()
    }

    private func startGeneration(
        systemPrompt: String,
        history: [ChatMessage],
        chat: Chat,
        context: ModelContext
    ) {
        isGenerating = true
        errorMessage = nil
        streamingBuffer = ""

        let assistantMsg = Message(role: .assistant, content: "")
        assistantMsg.isStreaming = true
        assistantMsg.chat = chat
        chat.messages.append(assistantMsg)
        context.insert(assistantMsg)

        let trimmedHistory = truncatedHistory(history, systemPrompt: systemPrompt)

        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var tokenCount = 0
            do {
                let stream = self.llmService.generate(systemPrompt: systemPrompt, history: trimmedHistory)
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    self.streamingBuffer += token
                    tokenCount += 1
                    // Write to SwiftData every 5 tokens — reduces re-render pressure on main thread.
                    if tokenCount % 5 == 0 {
                        assistantMsg.content = self.streamingBuffer
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    if assistantMsg.content.isEmpty {
                        assistantMsg.content = "⚠️ Failed to generate. Try again."
                    }
                }
            }
            if self.streamTask != nil {
                assistantMsg.content = self.streamingBuffer   // final flush
                assistantMsg.isStreaming = false
                self.streamingBuffer = ""
                self.isGenerating = false
                try? context.save()
            }
        }
    }
}
