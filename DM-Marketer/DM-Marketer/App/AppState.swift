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
    /// Active LLM service. Uses LlamaCppService for real on-device inference.
    /// Falls back to MockLLMService for SwiftUI previews.
    var llmService: any LLMService = LlamaCppService()

    /// Whether the active LLM service has a model loaded and ready.
    /// Kept here (not inside the service) so @Observable drives SwiftUI re-renders.
    var isModelLoaded: Bool = false

    /// Display name of the currently active model.
    var activeModelName: String?

    /// Pending deep-link chat ID written by the Share Extension.
    var pendingChatID: UUID?

    /// Set when the app is opened via dmmarketer://share. Cleared after the user picks a topic.
    var pendingShare: PendingShare?

    // MARK: - Helpers

    /// Non-empty when the last loadModel call failed. Cleared on success.
    var loadModelError: String?

    /// Load a model file into the service. Updates both the service flag and the observable flag.
    @MainActor
    func loadModel(at url: URL, displayName: String) async {
        do {
            try await llmService.loadModel(at: url)
            isModelLoaded = true
            activeModelName = displayName
            loadModelError = nil
        } catch {
            isModelLoaded = false
            loadModelError = error.localizedDescription
        }
    }

    /// Unload the current model. Resets both flags.
    func unloadModel() {
        llmService.unloadModel()
        isModelLoaded = false
        activeModelName = nil
    }
}
