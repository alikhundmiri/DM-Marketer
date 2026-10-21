import SwiftUI
import SwiftData

struct TopicsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Topic.createdAt, order: .reverse) private var topics: [Topic]

    @State private var showingNewTopic = false
    @State private var showingVoice = false
    @State private var showingStats = false
    @State private var isReadingPaste = false
    @State private var pasteError: String?

    var body: some View {
        NavigationStack {
            Group {
                if topics.isEmpty {
                    scrollableEmptyState
                } else {
                    topicList
                }
            }
            .safeAreaInset(edge: .bottom) { QuotaBar() }
            .navigationTitle("SlydeBack")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Second way in, besides the share sheet: Copy link in X, then paste here.
                // PasteButton reads the clipboard without the "Allow Paste?" prompt.
                ToolbarItem(placement: .topBarLeading) {
                    if isReadingPaste {
                        ProgressView()
                    } else {
                        PasteButton(payloadType: String.self) { strings in
                            guard let pasted = strings.first else { return }
                            Task { await handlePaste(pasted) }
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonBorderShape(.capsule)
                        .tint(.cfLip)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: EngagementsView()) {
                        Image(systemName: "tray.full")
                            .font(.title3)
                            .foregroundStyle(Color.cfLip)
                    }
                    .accessibilityLabel("Replies")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showingVoice = true } label: { Label("Your voice", systemImage: "text.quote") }
                        Button { showingStats = true } label: { Label("Your stats", systemImage: "chart.bar") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(Color.cfLip)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTopic = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.cfLip)
                    }
                }
            }
            .sheet(isPresented: $showingNewTopic) {
                TopicFormView()
            }
            .sheet(isPresented: $showingVoice) {
                VoiceCardView()
            }
            .sheet(isPresented: $showingStats) {
                StatsView()
            }
            .alert("Couldn't read that", isPresented: Binding(
                get: { pasteError != nil },
                set: { if !$0 { pasteError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(pasteError ?? "")
            }
        }
    }

    // MARK: - Empty state

    private var scrollableEmptyState: some View {
        ScrollView {
            MascotEmptyState(
                headline: "Flow starts here",
                subheadline: "Add what you promote. Then share a post to SlydeBack and get a reply written in your voice.",
                actionLabel: "Create your first topic",
                action: { showingNewTopic = true }
            )
        }
    }

    // MARK: - List

    private var topicList: some View {
        List {
            ForEach(topics) { topic in
                NavigationLink(destination: TopicDetailView(topic: topic)) {
                    TopicRow(topic: topic)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: deleteTopics)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Paste

    /// An X link is fetched with its thread; anything else is treated as text to reply to.
    private func handlePaste(_ pasted: String) async {
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), TweetFetcher.isTweetURL(url) {
            isReadingPaste = true
            defer { isReadingPaste = false }
            do {
                appState.pendingShare = PendingShare(try await TweetFetcher.fetch(url))
            } catch {
                pasteError = "Couldn't load that post. Check your connection and try again."
            }
        } else if !trimmed.isEmpty {
            let context = PostContext(
                url: "",
                platform: SourcePlatform.other.rawValue,
                thread: [],
                target: PostContext.Post(name: "", handle: "", text: String(trimmed.prefix(4000))),
                quoted: nil
            )
            appState.pendingShare = PendingShare(context)
        }
    }

    private func deleteTopics(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(topics[i]) }
    }
}

// MARK: - Topic row

private struct TopicRow: View {
    let topic: Topic

    var body: some View {
        HStack(spacing: 12) {
            // Flow accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient.cfPrimary)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                Text(topic.name)
                    .font(.headline)

                Text(topic.promotionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(
                        "\(topic.chats.count) \(topic.chats.count == 1 ? "chat" : "chats")",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                    if !topic.link.isEmpty {
                        Label("Link", systemImage: "link")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}
