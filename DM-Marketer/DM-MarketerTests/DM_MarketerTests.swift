import Testing
import Foundation
@testable import DM_Marketer

struct ContextCardTests {

    @Test func productCardIsCappedInThePrompt() {
        let topic = SharedTopic(
            id: UUID(), name: "Invoicer",
            promotionDescription: String(repeating: "z", count: 2000),
            link: "https://example.com"
        )
        let text = topic.promptText
        #expect(text.contains("Invoicer: "))
        #expect(text.filter { $0 == "z" }.count == ContextBudget.productCardLimit)
        #expect(text.contains("https://example.com"))
    }

    @Test func linkIsOmittedWhenEmpty() {
        let topic = SharedTopic(id: UUID(), name: "X", promotionDescription: "y", link: "")
        #expect(!topic.promptText.contains("Link"))
    }

    @Test func cardsFitTheModelWindowWithRoomToSpare() {
        // Rough 4 characters per token; the window is 4,096 tokens for instructions, prompt and output.
        let cards = ContextBudget.productCardLimit + ContextBudget.voiceCardLimit
        let conversation = 3000
        let instructionsAndFormat = 800
        let promptTokens = (cards + conversation + instructionsAndFormat) / 4
        #expect(promptTokens < 4096 - 512)
    }
}

struct PostContextTests {

    private func post(_ handle: String, _ text: String) -> PostContext.Post {
        PostContext.Post(name: handle.capitalized, handle: handle, text: text)
    }

    @Test func promptTextOrdersThreadTargetAndQuote() {
        let ctx = PostContext(
            url: "https://x.com/a/status/1", platform: "twitter",
            thread: [post("a", "first")],
            target: post("b", "second"),
            quoted: post("c", "third")
        )
        let text = ctx.promptText
        let first = text.range(of: "first")!.lowerBound
        let second = text.range(of: "second")!.lowerBound
        let third = text.range(of: "third")!.lowerBound
        #expect(first < second && second < third)
    }

    @Test func titleFallsBackToByline() {
        let ctx = PostContext(url: "", platform: "other", thread: [], target: post("b", ""), quoted: nil)
        #expect(ctx.title == "Post by @b")
    }

    @Test func summaryMentionsThreadAndQuote() {
        let ctx = PostContext(
            url: "", platform: "other",
            thread: [post("a", "x"), post("a", "y")],
            target: post("b", "z"),
            quoted: post("c", "q")
        )
        #expect(ctx.summary.contains("2 earlier"))
        #expect(ctx.summary.contains("quotes"))
    }
}

struct QuotaTests {

    @Test func unlockedAlwaysCanDraft() {
        let was = DraftQuota.isUnlocked
        defer { DraftQuota.isUnlocked = was }
        DraftQuota.isUnlocked = true
        #expect(DraftQuota.canDraft)
    }

    @Test func remainingNeverGoesNegative() {
        #expect(DraftQuota.remaining >= 0)
        #expect(DraftQuota.remaining <= DraftQuota.freeLimit)
    }

    @Test func engagementStartsWithoutAReply() {
        let item = PendingEngagement(postURL: "u", handle: "h", snippet: "s", draft: "d", kind: "Tweet reply")
        let engagement = Engagement(item)
        #expect(!engagement.gotReply)
        #expect(engagement.id == item.id)
    }
}
