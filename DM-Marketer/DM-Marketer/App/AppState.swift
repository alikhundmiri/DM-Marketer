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
    var llmService: any LLMService = LlamaCppService()

    /// Whether the active LLM service has a model loaded and ready.
    /// Kept here (not inside the service) so @Observable drives SwiftUI re-renders.
    var isModelLoaded: Bool = false

    /// True while loadModel() is in progress (file being read into memory).
    var isModelLoading: Bool = false

    /// Name of the model currently being loaded (shown in the chat loading state).
    var loadingModelName: String?

    /// Display name of the currently active model.
    var activeModelName: String?

    /// Last successfully loaded model — kept after unload so we can reload on foreground.
    private(set) var lastModelURL: URL?
    private(set) var lastModelDisplayName: String?

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
        guard !isModelLoading else { return }
        lastModelURL = url
        lastModelDisplayName = displayName
        isModelLoading = true
        loadingModelName = displayName
        loadModelError = nil
        let nCtx = LLMModel.contextWindow(forFilename: url.lastPathComponent)
        do {
            try await llmService.loadModel(at: url, nCtx: nCtx)
            isModelLoaded = true
            activeModelName = displayName
        } catch {
            isModelLoaded = false
            loadModelError = error.localizedDescription
        }
        isModelLoading = false
        loadingModelName = nil
    }

    /// Reload the last known model. Called when app returns to foreground after unloading.
    @MainActor
    func reloadLastModel() async {
        guard let url = lastModelURL, let name = lastModelDisplayName else { return }
        guard !isModelLoaded, !isModelLoading else { return }
        await loadModel(at: url, displayName: name)
    }

    /// Unload the current model. Resets both flags.
    func unloadModel() {
        llmService.unloadModel()
        isModelLoaded = false
        isModelLoading = false
        activeModelName = nil
        loadingModelName = nil
    }
}
