import UIKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import FoundationModels
import os

// Share sheet entry point. Two paths:
//   • Apple Intelligence available → read the post, write the draft right here, Copy & close.
//   • Otherwise → read the post, hand it to the app (App Group + notification), since the
//     downloaded models are far bigger than an extension's ~100 MB memory limit.
// A Diagnostics section keeps the spike's log for on-device testing.

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
        case handedOff        // saved for the app; notification posted
        case failed(String)
    }

    // Hard-coded until the app writes the active topic into the App Group.
    static let product = """
    ColdFlow: an iPhone app that drafts a personalised cold DM or reply from a post you share, \
    using AI that runs on your phone. One-time purchase, no subscription.
    """

    weak var extensionContext: NSExtensionContext?

    var phase: Phase = .reading
    var context: PostContext?
    var kind: DraftKind = .reply
    var draft = ""
    var notificationsAllowed = true
    var copied = false
    var log: [String] = []

    private let started = Date()
    private var session: LanguageModelSession?
    private var appleModelReady: Bool { session != nil }

    // MARK: Flow

    func start(items: [NSExtensionItem]) {
        noteMemory("launch")
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
            if appleModelReady {
                await generate()
            } else {
                await handOffToApp()
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
        guard let session, let context, !session.isResponding else { return }
        phase = .writing
        draft = ""
        let t0 = Date()
        noteMemory("before generate")
        do {
            for try await snapshot in session.streamResponse(to: Self.prompt(kind: kind, context: context)) {
                draft = snapshot.content
            }
            note("generated in \(Int(Date().timeIntervalSince(t0) * 1000))ms")
            noteMemory("after generate")
            phase = .drafted
        } catch {
            note("generation error: \(error)")
            phase = .failed("Apple Intelligence couldn't write this one. Try again, or open DM Marketer to use your downloaded model.")
        }
    }

    func regenerate() {
        // Fresh session per draft — one-shot task, no transcript worth keeping.
        session = LanguageModelSession(instructions: Self.instructions)
        Task { await generate() }
    }

    func copyAndClose() {
        UIPasteboard.general.string = draft
        copied = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            extensionContext?.completeRequest(returningItems: [])
        }
    }

    // MARK: Path B — hand off to the app

    private func handOffToApp() async {
        guard let context else { return }
        do {
            try PendingShareStore.save(context)
        } catch {
            note("save failed: \(error)")
            phase = .failed("Couldn't pass this post to DM Marketer.")
            return
        }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        notificationsAllowed = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        note("notifications: \(settings.authorizationStatus.rawValue)")
        if notificationsAllowed {
            let content = UNMutableNotificationContent()
            content.title = "Tap to write your reply"
            content.body = context.summary
            let request = UNNotificationRequest(identifier: "pending-share", content: content, trigger: nil)
            try? await center.add(request)
        }
        phase = .handedOff
        if notificationsAllowed {
            // The banner carries the next step; get out of the way so it's tappable over X.
            try? await Task.sleep(for: .milliseconds(1500))
            close()
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

    static func prompt(kind: DraftKind, context: PostContext) -> String {
        let format: String
        switch kind {
        case .reply: format = "A public reply to the post. Under 240 characters. Add value first; mention the product only if it fits naturally."
        case .dm:    format = "A private X DM to the post's author. Under 280 characters. Reference something specific they said, then a soft mention of the product."
        case .email: format = "A reply to the email. 3–5 short sentences, friendly and direct, signed off without a name."
        }
        return """
        PRODUCT:
        \(product)

        CONVERSATION:
        \(context.promptText.prefix(3000))

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

    func copyReport() {
        let device = UIDevice.current
        let header = "ColdFlow share — \(device.model) iOS \(device.systemVersion)"
        UIPasteboard.general.string = ([header] + log + ["", "CONTEXT:", context?.promptText ?? "", "", "DRAFT:", draft])
            .joined(separator: "\n")
    }

    func testOpenIntent() {
        var comps = URLComponents(string: "https://x.com/intent/post")!
        comps.queryItems = [URLQueryItem(name: "text", value: draft.isEmpty ? "test" : draft)]
        guard let url = comps.url, let ctx = extensionContext else { return }
        ctx.open(url) { ok in
            Task { @MainActor in self.note("extensionContext.open returned \(ok)") }
        }
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
                Section {
                    DisclosureGroup("Diagnostics") {
                        Button("Copy report") { share.copyReport() }
                        Button("Test: open X from the sheet") { share.testOpenIntent() }
                        ForEach(Array(share.log.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.caption2.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("DM Marketer")
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
                    Text("Copy, then paste it into X. Not quite right? Switch format or write another.")
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

        case .handedOff:
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saved \(share.context?.summary ?? "the post")").font(.headline)
                        Text(share.notificationsAllowed
                             ? "Tap the DM Marketer notification to write your reply with your downloaded model."
                             : "Open DM Marketer to write your reply — the post will be waiting.")
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                Button("Done") { share.close() }
                    .font(.headline)
            } footer: {
                Text("Writing right here in the share sheet needs Apple Intelligence (iPhone 15 Pro or newer).")
            }

        case .failed(let message):
            Section {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                Button("Close") { share.close() }
            }
        }
    }
}
