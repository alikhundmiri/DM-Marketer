import Foundation

// Compiled into both the app and the Share Extension.

/// Apple's on-device model has a 4,096-token window shared by instructions, prompt and output,
/// so the user's context lives on two short cards that are always included.
nonisolated enum ContextBudget {
    /// ~150 tokens each at ~4 characters per token.
    static let productCardLimit = 600
    static let voiceCardLimit = 500
}

/// How the user writes: tone, quirks, a sample line or two. Shared with the Share Extension
/// through the App Group; the app edits it with @AppStorage(VoiceCardStore.key, store: VoiceCardStore.defaults).
nonisolated enum VoiceCardStore {
    static let key = "voice-card"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: PendingShareStore.appGroup) ?? .standard
    }

    static var text: String {
        String((defaults.string(forKey: key) ?? "").prefix(ContextBudget.voiceCardLimit))
    }
}
