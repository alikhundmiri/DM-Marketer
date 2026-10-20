import Foundation

// Compiled into both the app and the Share Extension.

/// Free drafts before the one-time unlock. Counted per new post (rewrites and follow-ups are free),
/// and shared between the app and the share sheet through the App Group.
nonisolated enum DraftQuota {
    static let freeLimit = 10

    private static let usedKey = "drafts-used"
    private static let unlockedKey = "unlocked"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: PendingShareStore.appGroup) ?? .standard
    }

    static var used: Int { defaults.integer(forKey: usedKey) }

    /// Written by the app after StoreKit confirms the purchase; read by the share sheet.
    static var isUnlocked: Bool {
        get { defaults.bool(forKey: unlockedKey) }
        set { defaults.set(newValue, forKey: unlockedKey) }
    }

    static var remaining: Int { max(0, freeLimit - used) }
    static var canDraft: Bool { isUnlocked || remaining > 0 }

    static func consume() {
        guard !isUnlocked else { return }
        defaults.set(used + 1, forKey: usedKey)
    }
}
