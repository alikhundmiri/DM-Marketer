import Foundation

// Compiled into both the app and the Share Extension.

/// Hands a shared post from the Share Extension to the app through the App Group container.
///
/// Apple doesn't let extensions open their app, so on devices without Apple Intelligence the
/// extension saves the post here and posts a notification; the app picks it up when it opens.
nonisolated enum PendingShareStore {
    static let appGroup = "group.com.alikhundmiri.dm-marketer"

    /// Shares older than this are dropped rather than surprising the user later.
    static let maxAge: TimeInterval = 60 * 60

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("pending-share.json")
    }

    static func save(_ context: PostContext) throws {
        guard let url = fileURL else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(context).write(to: url, options: .atomic)
    }

    /// Returns the pending share and deletes it, so it's only handled once.
    static func take() -> PostContext? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        guard let context = try? JSONDecoder().decode(PostContext.self, from: data),
              Date().timeIntervalSince(context.sharedAt) < maxAge else { return nil }
        return context
    }
}
