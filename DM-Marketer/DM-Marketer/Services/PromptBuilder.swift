import Foundation

enum PromptBuilder {

    static func systemPrompt(topic: Topic, chat: Chat) -> String {
        let platformNote: String
        switch chat.sourcePlatform {
        case .twitter:
            platformNote = "Twitter/X — keep the DM under 280 characters. Be casual and direct."
        case .linkedin:
            platformNote = "LinkedIn — aim for 300–400 characters. Professional but warm, not corporate."
        case .reddit:
            platformNote = "Reddit — 250–350 characters. Conversational, community-minded tone. Don't sound like an ad."
        case .other:
            platformNote = "Keep the message concise, under 300 characters. Friendly and natural."
        }

        var postSection = ""
        if !chat.socialPostContent.isEmpty {
            postSection = """

SOCIAL MEDIA POST YOU ARE RESPONDING TO:
Platform: \(chat.sourcePlatform.rawValue)
---
\(chat.socialPostContent)
---
"""
        }

        return """
        You are a DM writing assistant helping with personalized marketing outreach.

        PRODUCT / SERVICE TO PROMOTE:
        \(topic.promotionDescription)

        LINK: \(topic.link)
        \(postSection)
        PLATFORM GUIDELINES: \(platformNote)

        RULES:
        - Acknowledge the person's specific pain point from their post (if provided).
        - Naturally connect it to the product — never sound like a bot or bulk-sender.
        - Include the link naturally, not as a raw URL dump.
        - Sound like a real human who genuinely thinks this will help them.
        - Output ONLY the DM text. No labels, no explanations, no quotes around it.

        When asked for variations, produce only the new DM text.
        """
    }

    static func firstUserMessage() -> String {
        "Generate a personalized DM for this person."
    }
}
