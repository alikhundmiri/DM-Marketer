import Foundation
import SwiftData

enum SourcePlatform: String, CaseIterable, Codable {
    case twitter  = "Twitter / X"
    case linkedin = "LinkedIn"
    case reddit   = "Reddit"
    case other    = "Other"

    var systemImage: String {
        switch self {
        case .twitter:  return "at"
        case .linkedin: return "briefcase"
        case .reddit:   return "bubble.left.and.bubble.right"
        case .other:    return "globe"
        }
    }

    /// Suggested max DM length for platform.
    var characterTarget: Int {
        switch self {
        case .twitter:  return 280
        case .linkedin: return 400
        case .reddit:   return 350
        case .other:    return 300
        }
    }
}

@Model
final class Chat {
    var id: UUID
    var title: String
    var socialPostContent: String   // The tweet / post / comment shared into the app
    var socialPostURL: String
    var sourcePlatformRaw: String   // stores SourcePlatform.rawValue
    var createdAt: Date

    var topic: Topic?

    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    var messages: [Message]

    var sourcePlatform: SourcePlatform {
        SourcePlatform(rawValue: sourcePlatformRaw) ?? .other
    }

    var sortedMessages: [Message] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    init(
        title: String,
        socialPostContent: String = "",
        socialPostURL: String = "",
        sourcePlatform: SourcePlatform = .other
    ) {
        self.id = UUID()
        self.title = title
        self.socialPostContent = socialPostContent
        self.socialPostURL = socialPostURL
        self.sourcePlatformRaw = sourcePlatform.rawValue
        self.createdAt = Date()
        self.messages = []
    }
}
