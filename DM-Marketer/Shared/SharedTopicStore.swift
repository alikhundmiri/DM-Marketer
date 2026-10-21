import Foundation

// Compiled into both the app and the Share Extension.

/// A plain copy of a Topic that the Share Extension can read.
nonisolated struct SharedTopic: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var promotionDescription: String
    var link: String

    /// The product block that goes into the prompt.
    var promptText: String {
        var text = "\(name): \(promotionDescription.prefix(ContextBudget.productCardLimit))"
        if !link.isEmpty { text += "\nLink (only if it fits): \(link)" }
        return text
    }
}

/// Copies the user's Topics into the App Group so the Share Extension drafts about the
/// user's real product. The app writes; the extension reads.
nonisolated enum SharedTopicStore {
    private static let topicsKey = "shared-topics"
    private static let lastUsedKey = "last-used-topic"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: PendingShareStore.appGroup)
    }

    static func save(_ topics: [SharedTopic]) {
        guard let data = try? JSONEncoder().encode(topics) else { return }
        defaults?.set(data, forKey: topicsKey)
    }

    static func load() -> [SharedTopic] {
        guard let data = defaults?.data(forKey: topicsKey),
              let topics = try? JSONDecoder().decode([SharedTopic].self, from: data) else { return [] }
        return topics
    }

    static var lastUsedID: UUID? {
        get { defaults?.string(forKey: lastUsedKey).flatMap(UUID.init(uuidString:)) }
        set { defaults?.set(newValue?.uuidString, forKey: lastUsedKey) }
    }
}
