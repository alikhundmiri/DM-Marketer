import Foundation

// Compiled into both the app and the Share Extension.

/// A shared post plus the conversation around it — what the model needs to write a reply.
nonisolated struct PostContext: Codable, Equatable, Sendable {
    nonisolated struct Post: Codable, Equatable, Sendable {
        var name: String     // display name, e.g. "Wes Winder"
        var handle: String   // without "@", may be empty when unknown
        var text: String

        var byline: String { handle.isEmpty ? name : "@\(handle)" }
    }

    var url: String
    var platform: String     // SourcePlatform raw value
    var thread: [Post]       // earlier posts in the thread, oldest first
    var target: Post         // the post that was shared
    var quoted: Post?        // the post it quotes, if any
    var sharedAt = Date()

    /// Short title for the chat list.
    var title: String {
        let words = target.text.split(whereSeparator: \.isWhitespace).prefix(6).joined(separator: " ")
        return words.isEmpty ? "Post by \(target.byline)" : "\(target.byline): \(words)"
    }

    /// Plain-text block stored on Chat.socialPostContent and fed to the model.
    var promptText: String {
        var parts: [String] = []
        if !thread.isEmpty {
            parts.append("Earlier in the thread:\n" + thread.map { "\($0.byline): \($0.text)" }.joined(separator: "\n"))
        }
        let lead = thread.isEmpty ? target.byline : "The post you're responding to, \(target.byline)"
        parts.append("\(lead): \(target.text)")
        if let quoted {
            parts.append("It quotes \(quoted.byline): \(quoted.text)")
        }
        return parts.joined(separator: "\n\n")
    }

    /// One-line summary for status UI, e.g. "@wes's post + 3 earlier in the thread".
    var summary: String {
        var s = "\(target.byline)'s post"
        if !thread.isEmpty { s += " + \(thread.count) earlier in the thread" }
        if quoted != nil { s += " + the post it quotes" }
        return s
    }
}
