import Foundation

enum PromptBuilder {

    static func systemPrompt(topic: Topic, chat: Chat) -> String {
        let platformGuide: String
        switch chat.sourcePlatform {
        case .twitter:
            platformGuide = "This is a Twitter/X DM. Hard limit: 280 characters. Tone: casual, punchy, like texting. No corporate words. Sound like a real person, not a brand."
        case .linkedin:
            platformGuide = "This is a LinkedIn DM. Target: 300–400 characters. Warm and direct, like a peer reaching out — NOT a recruiter pitch or sales email. First-name energy."
        case .reddit:
            platformGuide = "This is a Reddit DM. Target: 250–350 characters. Sound like a fellow community member who has relevant experience. Never sound promotional or like spam."
        case .other:
            platformGuide = "Keep it under 300 characters. Conversational and human, like you're talking to someone you just met."
        }

        let postSection: String
        if chat.socialPostContent.isEmpty {
            postSection = ""
        } else {
            postSection = """

---
THE POST YOU ARE RESPONDING TO (\(chat.sourcePlatform.rawValue)):
\(chat.socialPostContent)
---

TONE ANALYSIS INSTRUCTIONS:
Before writing the DM, silently observe:
- Is the person frustrated, excited, curious, humorous? Mirror that energy.
- Do they use short sentences or long ones? Match their rhythm.
- Do they use slang, technical terms, or formal language? Adapt accordingly.
- What is the CORE pain point or feeling in their post? Build the DM around that.

"""
        }

        // Trim product description to keep prompt focused
        let rawDesc = topic.promotionDescription
        let productDesc = rawDesc.count > 600
            ? String(rawDesc.prefix(600)) + "…"
            : rawDesc

        return """
        You are helping write a single outreach DM on behalf of the maker of this product.

        VOICE: You are a real person — the founder or maker — not a marketing bot. You write the way you talk. You are genuinely trying to help, not sell. You reached out because something in their post clicked with a problem you solved.

        PRODUCT / SERVICE TO PROMOTE:
        \(productDesc)
        \(postSection)
        PLATFORM: \(platformGuide)

        WRITING GUIDELINES:
        1. Write for this specific person — their post, their words, their situation. If it could be sent to anyone, rewrite it.
        2. Pull something concrete from their post — a phrase they used, a feeling they expressed, a specific situation they described.
        3. No URLs or links in the body — the link gets shared separately.
        4. Avoid worn-out openers: "I came across your post", "I noticed you", "resonated with me", "I'd love to connect", "I thought you might be interested", "I wanted to reach out".
        5. Write in plain prose — no em dashes, no bullet points, no formatting tricks.
        6. Skip the generic warmup. Lead with something real, specific, or surprising.
        7. Output only the DM text — no labels, no quotes, no explanation.
        8. Respect the character limit for the platform.

        When asked for a variation, write a completely different version — different opener, different angle, different sentence structure.
        """
    }

    static func firstUserMessage() -> String {
        "Write the DM."
    }

    static func variationUserMessage() -> String {
        "Write a completely different version with a fresh angle."
    }
}
