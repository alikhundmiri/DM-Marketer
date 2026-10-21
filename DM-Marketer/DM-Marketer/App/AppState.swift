import Foundation
import FoundationModels

/// Data received from the Share Extension via the dmmarketer://share URL scheme.
struct PendingShare: Identifiable {
    /// Stable identity so the picker sheet isn't re-presented on every redraw.
    let id = UUID()
    var text: String
    var url: String
    var platform: String
    var title: String = ""
}

extension PendingShare {
    init(_ context: PostContext) {
        self.init(text: context.promptText, url: context.url, platform: context.platform, title: context.title)
    }
}

/// Central state shared across the app via SwiftUI's @Observable + .environment().
/// @Observable (iOS 17) handles any stored property type — no @Published, no Combine.
@Observable
final class AppState {
    /// Active LLM service: Apple's on-device model.
    var llmService: any LLMService = AppleModelService()

    /// Whether Apple Intelligence is ready to write.
    /// Kept here (not inside the service) so @Observable drives SwiftUI re-renders.
    var isModelLoaded: Bool = false

    /// Why Apple Intelligence can't write right now; nil when it can.
    var unavailableReason: SystemLanguageModel.Availability.UnavailableReason?

    /// Pending deep-link chat ID written by the Share Extension.
    var pendingChatID: UUID?

    /// Set when the app is opened via dmmarketer://share. Cleared after the user picks a topic.
    var pendingShare: PendingShare?

    /// Re-check Apple Intelligence. Call at launch and whenever the app returns to the foreground,
    /// since the user may have just turned it on in Settings.
    func refreshAvailability() {
        switch SystemLanguageModel.default.availability {
        case .available:
            isModelLoaded = true
            unavailableReason = nil
        case .unavailable(let reason):
            isModelLoaded = false
            unavailableReason = reason
        }
    }
}
