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

        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let stream = self.llmService.generate(systemPrompt: systemPrompt, history: history)
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    self.streamingBuffer += token
                    assistantMsg.content = self.streamingBuffer
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    if assistantMsg.content.isEmpty {
                        assistantMsg.content = "⚠️ Failed to generate. Try again."
                    }
                }
            }
            // Only update final state if this task wasn't superseded by cancelGeneration()
            if self.streamTask != nil {
                assistantMsg.isStreaming = false
                self.streamingBuffer = ""
                self.isGenerating = false
                try? context.save()
            }
        }
    }
}
