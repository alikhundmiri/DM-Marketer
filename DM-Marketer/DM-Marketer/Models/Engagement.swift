import Foundation
import SwiftData

/// A reply the user drafted with the app. They tap "Got a reply" when the other person answers.
@Model
final class Engagement {
    var id: UUID
    var postURL: String
    var handle: String
    var snippet: String
    var draft: String
    var kind: String
    var createdAt: Date
    var gotReply: Bool

    init(_ item: PendingEngagement) {
        self.id = item.id
        self.postURL = item.postURL
        self.handle = item.handle
        self.snippet = item.snippet
        self.draft = item.draft
        self.kind = item.kind
        self.createdAt = item.date
        self.gotReply = false
    }
}
