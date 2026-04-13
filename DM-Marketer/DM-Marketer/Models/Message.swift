import Foundation
import SwiftData

enum MessageRole: String, Codable {
    case user      = "user"
    case assistant = "assistant"
}

@Model
final class Message {
    var id: UUID
    var roleRaw: String
    var content: String
    var createdAt: Date
    var isStreaming: Bool

    var chat: Chat?

    var role: MessageRole {
        MessageRole(rawValue: roleRaw) ?? .user
    }

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.content = content
        self.createdAt = Date()
        self.isStreaming = false
    }
}
