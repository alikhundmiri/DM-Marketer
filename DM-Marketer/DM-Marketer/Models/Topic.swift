import Foundation
import SwiftData

@Model
final class Topic {
    var id: UUID
    var name: String
    var promotionDescription: String
    var link: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Chat.topic)
    var chats: [Chat]

    init(name: String, promotionDescription: String, link: String) {
        self.id = UUID()
        self.name = name
        self.promotionDescription = promotionDescription
        self.link = link
        self.createdAt = Date()
        self.chats = []
    }
}
