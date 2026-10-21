import UIKit
import SwiftUI
import UniformTypeIdentifiers
import FoundationModels
import os

// Share sheet entry point: read the post, write the draft right here with Apple Intelligence,
// Copy & close. Devices without Apple Intelligence are told so.

class ShareViewController: UIViewController {

    private let share = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        share.extensionContext = extensionContext

        let host = UIHostingController(rootView: ShareSheetView(share: share))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        share.start(items: extensionContext?.inputItems as? [NSExtensionItem] ?? [])
    }
}

// MARK: - Model

enum DraftKind: String, CaseIterable, Identifiable {
    case reply = "Tweet reply"
    case dm    = "X DM"
    case email = "Email reply"
    var id: String { rawValue }
}

@MainActor
@Observable
final class ShareModel {
    enum Phase: Equatable {
        case reading
        case writing          // Apple model generating in the sheet
        case drafted          // draft ready to copy
        case failed(String)
    }

    /// The user's Topics, copied into the App Group by the app.
    var topics: [SharedTopic] = SharedTopicStore.load()
    var selectedTopicID: UUID?

    var selectedTopic: SharedTopic? {
        topics.first { $0.id == selectedTopicID } ?? topics.first
    }

    weak var extensionContext: NSExtensionContext?

    var phase: Phase = .reading
    var context: PostContext?
    var kind: DraftKind = .reply
    var draft = ""
    var copied = false
    private var countedThisShare = false
    /// Optional steer from the user, e.g. "show empathy, mention X, then pitch".
    var hint = ""
    static let hintLimit = 300
    /// Characters of conversation sent to the model; lowered if the 4,096-token window overflows.
    private var conversationLimit = 3000

    var quotaText: String {
        DraftQuota.isUnlocked ? "" : "\(DraftQuota.remaining) of \(DraftQuota.freeLimit) free drafts left."
    }
    var log: [String] = []

    private let started = Date()
    private var session: LanguageModelSession?
    private var appleModelReady: Bool { session != nil }

    // MARK: Flow

    func start(items: [NSExtensionItem]) {
        noteMemory("launch")
        UsageStats.recordActiveDay()
        selectedTopicID = SharedTopicStore.lastUsedID.flatMap { id in topics.first { $0.id == id }?.id } ?? topics.first?.id
        prepareAppleModel()   // prewarm while we fetch the post
        Task {
            let (url, text) = await extractInputs(items)
            do {
                context = try await buildContext(url: url, text: text)
                note("context: \(context!.summary)")
            } catch {
                note("context failed: \(error.localizedDescription)")
                phase = .failed("Couldn't read this post. Check your connection and try again.")
                return
            }
            if topics.isEmpty {
                phase = .failed("Add what you're promoting in SlydeBack first, then share again.")
            } else if appleModelReady {
                await generate()
            } else {
                phase = .failed("SlydeBack needs Apple Intelligence (iPhone 15 Pro or newer). Open the app to check your device.")
            }
        }
    }

    private func prepareAppleModel() {
        switch SystemLanguageModel.default.availability {
        case .available:
            note("Apple model: available")
            let session = LanguageModelSession(instructions: Self.instructions)
            session.prewarm()
            self.session = session
        case .unavailable(let reason):
            note("Apple model: unavailable — \(reason)")
        }
    }

    private func extractInputs(_ items: [NSExtensionItem]) async -> (URL?, String) {
        var url: URL?
        var text = ""
        for item in items {
            if let t = item.attributedContentText?.string, !t.isEmpty, text.isEmpty { text = t }
            for provider in item.attachments ?? [] {
                note("attachment types: \(provider.registeredTypeIdentifiers.joined(separator: ", "))")
                if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let u = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL,
                   !u.isFileURL {
                    url = u
                }
                if text.isEmpty, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let t = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    if let u = URL(string: t.trimmingCharacters(in: .whitespacesAndNewlines)), u.scheme?.hasPrefix("http") == true {
                        url = url ?? u
                    } else {
                        text = t
                    }
                }
            }
        }
        note("url: \(url?.absoluteString ?? "none"), text: \(text.prefix(120))")
        return (url, text)
    }

    private func buildContext(url: URL?, text: String) async throws -> PostContext {
        if let url, TweetFetcher.isTweetURL(url) {
            let t0 = Date()
            let ctx = try await TweetFetcher.fetch(url)
            note("fetched in \(Int(Date().timeIntervalSince(t0) * 1000))ms")
            kind = .reply
            return ctx
        }
        guard !text.isEmpty else { throw URLError(.zeroByteResource) }
        // Shared text (e.g. selected from an email) — treat as an email to reply to.
        kind = .email
        return PostContext(
            url: url?.absoluteString ?? "",
            platform: "Other",
            thread: [],
            target: PostContext.Post(name: "", handle: "", text: String(text.prefix(4000))),
            quoted: nil
        )
    }

    // MARK: Path A — Apple model in the sheet

    func generate() async {
        guard let session, let context, let topic = selectedTopic, !session.isResponding else { return }
        if !countedThisShare, !DraftQuota.canDraft {
            phase = .failed("You've used your \(DraftQuota.freeLimit) free drafts. Open SlydeBack to unlock unlimited drafts.")
            return
        }
        SharedTopicStore.lastUsedID = topic.id
        phase = .writing
        draft = ""
        let t0 = Date()
        noteMemory("before generate")
        do {
            for try await snapshot in session.streamResponse(to: Self.prompt(kind: kind, topic: topic, context: context, conversationLimit: conversationLimit, hint: hint)) {
                draft = snapshot.content
            }
            note("generated in \(Int(Date().timeIntervalSince(t0) * 1000))ms")
            noteMemory("after generate")
            UsageStats.recordDraft(milliseconds: Int(Date().timeIntervalSince(t0) * 1000))
            if !countedThisShare {
                DraftQuota.consume()
                countedThisShare = true
            }
            phase = .drafted
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error, conversationLimit > 800 {
                // Long thread: retry once with less of it.
                conversationLimit = 800
                self.session = LanguageModelSession(instructions: Self.instructions)
                await generate()
                return
            }
            UsageStats.recordError()
            note("generation error: \(error)")
            phase = .failed("Apple Intelligence couldn't write this one. Try again in a moment.")
        } catch {
            UsageStats.recordError()
            note("generation error: \(error)")
            phase = .failed("Apple Intelligence couldn't write this one. Try again in a moment.")
        }
    }

    func regenerate() {
        UsageStats.recordRewrite()
        // Fresh session per draft — one-shot task, no transcript worth keeping.
        session = LanguageModelSession(instructions: Self.instructions)
        Task { await generate() }
    }

    func copyAndClose() {
        UIPasteboard.general.string = draft
        copied = true
        UsageStats.recordCopy()
        if let context {
            EngagementInbox.append(PendingEngagement(
                postURL: context.url,
                handle: context.target.handle,
                snippet: String(context.target.text.prefix(140)),
                draft: draft,
                kind: kind.rawValue
            ))
        }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            extensionContext?.completeRequest(returningItems: [])
        }
    }

    func close() {
        extensionContext?.completeRequest(returningItems: [])
    }

    // MARK: Prompt

    static let instructions = """
    You write short, human outreach messages on behalf of an indie app maker. \
    Write like a real person, not a brand. Be specific to the post and the conversation around it. \
    No hashtags, no links, no em dashes. Output only the message text.
    """

    static func prompt(kind: DraftKind, topic: SharedTopic, context: PostContext, conversationLimit: Int, hint: String) -> String {
        let format: String
        switch kind {
        case .reply: format = "A public reply to the post. Under 240 characters. Add value first; mention the product only if it fits naturally."
        case .dm:    format = "A private X DM to the post's author. Under 280 characters. Reference something specific they said, then a soft mention of the product."
        case .email: format = "A reply to the email. 3–5 short sentences, friendly and direct, signed off without a name."
        }
        let voice = VoiceCardStore.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let voiceSection = voice.isEmpty ? "" : "\nMY VOICE (write the way I write):\n\(voice)\n"
        let steer = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        let hintSection = steer.isEmpty ? "" : "\nDIRECTION FROM ME (follow this when writing):\n\(steer.prefix(hintLimit))\n"
        return """
        PRODUCT:
        \(topic.promptText)
        \(voiceSection)\(hintSection)
        CONVERSATION:
        \(context.promptText.prefix(conversationLimit))

        FORMAT: \(format)
        """
    }

    // MARK: Diagnostics

    func note(_ line: String) {
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        log.append("[\(ms)ms] \(line)")
    }

    func noteMemory(_ label: String) {
        note("MEM \(label): available=\(os_proc_available_memory() / 1_048_576) MB")
    }
}

// MARK: - View

struct ShareSheetView: View {
    @Bindable var share: ShareModel

    var body: some View {
        NavigationStack {
            List {
                statusSection
                if let context = share.context {
                    Section("What I read") {
                        Text(context.promptText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(8)
                    }
                }
            }
            .navigationTitle("SlydeBack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { share.close() }
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch share.phase {
        case .reading:
            Section {
                Label {
                    Text("Reading the post and its thread…")
                } icon: {
                    ProgressView()
                }
            }

        case .writing, .drafted:
            Section {
                if share.topics.count > 1 {
                    Picker("Promoting", selection: $share.selectedTopicID) {
                        ForEach(share.topics) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .onChange(of: share.selectedTopicID) { share.regenerate() }
                }
                Picker("Format", selection: $share.kind) {
                    ForEach(DraftKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: share.kind) { share.regenerate() }

                if share.draft.isEmpty {
                    Label { Text("Writing with Apple Intelligence…") } icon: { ProgressView() }
                } else {
                    Text(share.draft).textSelection(.enabled)
                }
            } footer: {
                if share.phase == .drafted {
                    Text("Copy, then paste it into X. Not quite right? Switch format or write another. \(share.quotaText)")
                }
            }
            Section {
                Button {
                    share.copyAndClose()
                } label: {
                    Label(share.copied ? "Copied — paste it in X" : "Copy & close",
                          systemImage: share.copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.headline)
                }
                .disabled(share.phase != .drafted || share.copied)
                Button("Write another version") { share.regenerate() }
                    .disabled(share.phase != .drafted)
            }
            Section {
                TextField("e.g. show empathy, mention X and Y, then pitch", text: $share.hint, axis: .vertical)
                    .lineLimit(1...4)
                    .onChange(of: share.hint) { _, new in
                        if new.count > ShareModel.hintLimit { share.hint = String(new.prefix(ShareModel.hintLimit)) }
                    }
                Button("Write with this direction") { share.regenerate() }
                    .disabled(share.phase != .drafted || share.hint.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Steer the reply")
            } footer: {
                Text("\(share.hint.count)/\(ShareModel.hintLimit)")
            }

        case .failed(let message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                Button("Close") { share.close() }
            }
        }
    }
}
