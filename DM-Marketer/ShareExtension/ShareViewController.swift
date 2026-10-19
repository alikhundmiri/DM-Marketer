import UIKit
import SwiftUI
import UniformTypeIdentifiers
import FoundationModels
import os

// SPIKE (branch spike/share-sheet) — diagnostic share sheet, not product UI.
// Answers three questions on a real device:
//   1. Can Apple's on-device model run inside a share extension, and how much memory is left?
//   2. What does X (and Mail) actually hand to the share sheet?
//   3. Can an extension open an X intent URL? (Apple says no — we log the real result.)
// Tap "Copy report" and paste the result back into Claude Code.

class ShareViewController: UIViewController {

    private let spike = SpikeModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        spike.extensionContext = extensionContext

        let host = UIHostingController(rootView: SpikeView(spike: spike))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        spike.start(items: extensionContext?.inputItems as? [NSExtensionItem] ?? [])
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
final class SpikeModel {
    // Hard-coded for the spike — the extension can't read SwiftData Topics yet.
    static let product = """
    ColdFlow: an iPhone app that drafts a personalised cold DM or reply from a post you share, \
    using AI that runs on your phone. One-time purchase, no subscription.
    """

    weak var extensionContext: NSExtensionContext?

    var log: [String] = []
    var postText = ""
    var postAuthor = ""
    var sharedURL: URL?
    var kind: DraftKind = .reply
    var draft = ""
    var isGenerating = false

    private let started = Date()
    private var session: LanguageModelSession?

    // MARK: Logging

    func note(_ line: String) {
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        log.append("[\(ms)ms] \(line)")
    }

    func noteMemory(_ label: String) {
        let availMB = os_proc_available_memory() / 1_048_576
        note("MEM \(label): available=\(availMB) MB, footprint=\(Self.footprintMB()) MB")
    }

    private static func footprintMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Int(info.phys_footprint / 1_048_576) : -1
    }

    var report: String {
        let device = UIDevice.current
        let header = "ColdFlow spike — \(device.model) iOS \(device.systemVersion), RAM \(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) GB"
        return ([header] + log + ["", "DRAFT (\(kind.rawValue)):", draft]).joined(separator: "\n")
    }

    // MARK: Flow

    func start(items: [NSExtensionItem]) {
        noteMemory("launch")
        checkModel()   // prewarm in parallel with input extraction
        Task {
            await dumpInputs(items)
            await fetchTweetTextIfNeeded()
            if postText.isEmpty {
                note("No post text found — nothing to personalise from.")
            } else {
                await generate()
            }
        }
    }

    private func checkModel() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            note("Apple model: AVAILABLE")
            let session = LanguageModelSession(instructions: Self.instructions)
            self.session = session
            session.prewarm()
            note("prewarm() called")
            noteMemory("after prewarm")
        case .unavailable(let reason):
            note("Apple model: UNAVAILABLE — \(reason)")
        }
    }

    // Question 2: log everything the host app offers.
    private func dumpInputs(_ items: [NSExtensionItem]) async {
        note("inputItems: \(items.count)")
        for (i, item) in items.enumerated() {
            if let text = item.attributedContentText?.string, !text.isEmpty {
                note("item[\(i)] attributedContentText: \(text.prefix(300))")
                if postText.isEmpty { postText = text }
            }
            if let title = item.attributedTitle?.string { note("item[\(i)] attributedTitle: \(title)") }
            for (j, provider) in (item.attachments ?? []).enumerated() {
                note("item[\(i)].att[\(j)] types: \(provider.registeredTypeIdentifiers.joined(separator: ", "))")
                for type in provider.registeredTypeIdentifiers {
                    await load(provider, typeID: type, label: "item[\(i)].att[\(j)] \(type)")
                }
            }
        }
    }

    private func load(_ provider: NSItemProvider, typeID: String, label: String) async {
        do {
            let value = try await provider.loadItem(forTypeIdentifier: typeID)
            switch value {
            case let url as URL:
                note("\(label) = URL \(url.absoluteString)")
                if sharedURL == nil, !url.isFileURL { sharedURL = url }
            case let text as String:
                note("\(label) = String \(text.prefix(300))")
                if postText.isEmpty, URL(string: text)?.scheme == nil { postText = text }
                if sharedURL == nil, let url = URL(string: text), url.scheme?.hasPrefix("http") == true { sharedURL = url }
            case let data as Data:
                note("\(label) = Data \(data.count) bytes")
            default:
                note("\(label) = \(type(of: value as Any)) \(String(describing: value).prefix(200))")
            }
        } catch {
            note("\(label) load failed: \(error.localizedDescription)")
        }
    }

    // X shares a link; fetch the tweet text from X's keyless oEmbed endpoint.
    private func fetchTweetTextIfNeeded() async {
        guard let url = sharedURL,
              let host = url.host, host.hasSuffix("x.com") || host.hasSuffix("twitter.com"),
              url.path.contains("/status/") else { return }
        var comps = URLComponents(string: "https://publish.x.com/oembed")!
        comps.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "omit_script", value: "1"),
        ]
        do {
            let t0 = Date()
            let (data, _) = try await URLSession.shared.data(from: comps.url!)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let html = json?["html"] as? String ?? ""
            postAuthor = json?["author_name"] as? String ?? ""
            let text = Self.tweetText(fromEmbedHTML: html)
            note("oEmbed \(Int(Date().timeIntervalSince(t0) * 1000))ms → @\(postAuthor): \(text.prefix(200))")
            if !text.isEmpty { postText = text }
        } catch {
            note("oEmbed failed: \(error.localizedDescription)")
        }
    }

    static func tweetText(fromEmbedHTML html: String) -> String {
        guard let open = html.range(of: "<p"),
              let gt = html.range(of: ">", range: open.upperBound..<html.endIndex),
              let close = html.range(of: "</p>", range: gt.upperBound..<html.endIndex)
        else { return "" }
        var s = String(html[gt.upperBound..<close.lowerBound])
        s = s.replacingOccurrences(of: "<br>", with: "\n")
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, char) in ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&mdash;": "—"] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Question 1: generate inside the extension, logging memory and latency.
    func generate() async {
        guard let session else { note("Skipping generation — Apple model unavailable."); return }
        guard !session.isResponding else { return }
        isGenerating = true
        draft = ""
        defer { isGenerating = false }

        let prompt = Self.prompt(kind: kind, post: postText, author: postAuthor)
        let t0 = Date()
        var firstToken: Date?
        noteMemory("before generate (\(kind.rawValue))")
        do {
            for try await snapshot in session.streamResponse(to: prompt) {
                if firstToken == nil {
                    firstToken = Date()
                    note("first token after \(Int(firstToken!.timeIntervalSince(t0) * 1000))ms")
                    noteMemory("first token")
                }
                draft = snapshot.content
            }
            note("done in \(Int(Date().timeIntervalSince(t0) * 1000))ms, \(draft.count) chars")
            noteMemory("after generate")
        } catch {
            note("generation error: \(error)")
            noteMemory("after error")
        }
    }

    func regenerate() {
        // Fresh session per draft — this is a one-shot task, no transcript to keep.
        session = LanguageModelSession(instructions: Self.instructions)
        Task { await generate() }
    }

    // Question 3: can a share extension open a URL at all?
    func testOpenIntent() {
        let text = draft.isEmpty ? "test" : draft
        var comps = URLComponents(string: "https://x.com/intent/post")!
        comps.queryItems = [URLQueryItem(name: "text", value: text)]
        if let id = sharedURL?.pathComponents.last, sharedURL?.path.contains("/status/") == true {
            comps.queryItems?.append(URLQueryItem(name: "in_reply_to", value: id))
        }
        guard let url = comps.url, let ctx = extensionContext else { return }
        note("extensionContext.open(\(url.absoluteString.prefix(80))…)")
        ctx.open(url) { ok in
            Task { @MainActor in self.note("open returned \(ok)") }
        }
    }

    func copyDraftAndClose() {
        UIPasteboard.general.string = draft
        extensionContext?.completeRequest(returningItems: [])
    }

    func copyReport() {
        UIPasteboard.general.string = report
        note("Report copied to clipboard.")
    }

    func close() {
        extensionContext?.completeRequest(returningItems: [])
    }

    // MARK: Prompt

    static let instructions = """
    You write short, human outreach messages on behalf of an indie app maker. \
    Write like a real person, not a brand. Be specific to the post. \
    No hashtags, no links, no em dashes. Output only the message text.
    """

    static func prompt(kind: DraftKind, post: String, author: String) -> String {
        let format: String
        switch kind {
        case .reply: format = "A public reply to their tweet. Under 240 characters. Add value first; mention the product only if it fits naturally."
        case .dm:    format = "A private X DM. Under 280 characters. Reference something specific from their post, then a soft mention of the product."
        case .email: format = "A reply to the email below. 3–5 short sentences, friendly and direct, signed off without a name."
        }
        let who = author.isEmpty ? "" : " by \(author)"
        return """
        PRODUCT:
        \(product)

        POST\(who):
        \(post.prefix(2000))

        FORMAT: \(format)
        """
    }
}

// MARK: - View

struct SpikeView: View {
    @Bindable var spike: SpikeModel

    var body: some View {
        NavigationStack {
            List {
                Section("Draft") {
                    Picker("Format", selection: $spike.kind) {
                        ForEach(DraftKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: spike.kind) { spike.regenerate() }

                    if spike.isGenerating && spike.draft.isEmpty {
                        ProgressView("Writing…")
                    } else {
                        Text(spike.draft.isEmpty ? "No draft yet" : spike.draft)
                            .textSelection(.enabled)
                    }
                    Button("Copy draft & close") { spike.copyDraftAndClose() }
                        .disabled(spike.draft.isEmpty)
                    Button("Regenerate") { spike.regenerate() }
                        .disabled(spike.isGenerating)
                    Button("Test: open X intent from extension") { spike.testOpenIntent() }
                }
                Section("Report") {
                    Button("Copy report") { spike.copyReport() }
                    ForEach(Array(spike.log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("ColdFlow spike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { spike.close() }
                }
            }
        }
    }
}
