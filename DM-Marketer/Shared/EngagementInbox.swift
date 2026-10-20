import Foundation

// Compiled into both the app and the Share Extension.

/// A reply the user copied from the share sheet. The extension queues these; the app turns them
/// into Engagements the next time it opens.
nonisolated struct PendingEngagement: Codable, Identifiable {
    var id = UUID()
    var postURL: String
    var handle: String
    var snippet: String
    var draft: String
    var kind: String
    var date = Date()
}

nonisolated enum EngagementInbox {
    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: PendingShareStore.appGroup)?
            .appendingPathComponent("engagement-inbox.json")
    }

    static func append(_ item: PendingEngagement) {
        guard let url = fileURL else { return }
        var items = read(url)
        items.append(item)
        try? JSONEncoder().encode(items).write(to: url, options: .atomic)
    }

    /// Returns the queued items and clears the queue.
    static func takeAll() -> [PendingEngagement] {
        guard let url = fileURL else { return [] }
        let items = read(url)
        try? FileManager.default.removeItem(at: url)
        return items
    }

    private static func read(_ url: URL) -> [PendingEngagement] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PendingEngagement].self, from: data)) ?? []
    }
}
