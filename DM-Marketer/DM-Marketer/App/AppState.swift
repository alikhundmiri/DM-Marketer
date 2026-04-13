import Foundation

/// Data received from the Share Extension via the dmmarketer://share URL scheme.
struct PendingShare {
    var text: String
    var url: String
    var platform: String
}

/// Central state shared across the app via SwiftUI's @Observable + .environment().
/// @Observable (iOS 17) handles any stored property type — no @Published, no Combine.
@Observable
final class AppState {
    /// Active LLM service. MockLLMService by default; swap when a real model is loaded.
    var llmService: any LLMService = MockLLMService()

    /// Display name of the currently active model.
    var activeModelName: String?

    /// Pending deep-link chat ID written by the Share Extension.
    var pendingChatID: UUID?

    /// Set when the app is opened via dmmarketer://share. Cleared after the user picks a topic.
    var pendingShare: PendingShare?
}
