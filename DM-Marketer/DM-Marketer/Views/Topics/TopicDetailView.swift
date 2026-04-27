import SwiftUI
import SwiftData

struct TopicDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let topic: Topic

    @State private var showingNewChat = false
    @State private var showingEditTopic = false
    @State private var navigateToChat: Chat?

    private var sortedChats: [Chat] {
        topic.chats.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            // ── CHATS (top) ──────────────────────────────────────────────
            Section {
                if sortedChats.isEmpty {
                    emptyChatsPlaceholder
                } else {
                    ForEach(sortedChats) { chat in
                        NavigationLink(destination: ChatView(chat: chat, topic: topic)) {
                            ChatRow(chat: chat)
                        }
                    }
                    .onDelete(perform: deleteChats)
                }
            } header: {
                HStack {
                    Text("Chats")
                        .font(.headline)
                        .textCase(nil)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        showingNewChat = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("New Chat")
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }

            // ── TOPIC DETAILS (bottom, collapsed) ────────────────────────
            Section {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(topic.promotionDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !topic.link.isEmpty, let url = URL(string: topic.link) {
                            Link(topic.link, destination: url)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 6)
                } label: {
                    Label("What you're promoting", systemImage: "megaphone")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(topic.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditTopic = true }
            }
        }
        .navigationDestination(item: $navigateToChat) { chat in
            ChatView(chat: chat, topic: topic)
        }
        .sheet(isPresented: $showingNewChat) {
            NewChatView(topic: topic) { createdChat in
                showingNewChat = false
                navigateToChat = createdChat
            }
        }
        .sheet(isPresented: $showingEditTopic) {
            TopicFormView(topic: topic)
        }
    }

    private var emptyChatsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No chats yet")
                .font(.headline)
            Text("Tap New Chat, or share a post from Twitter, LinkedIn, or Reddit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .listRowBackground(Color.clear)
        .frame(maxWidth: .infinity)
    }

    private func deleteChats(at offsets: IndexSet) {
        let chats = sortedChats
        for i in offsets { modelContext.delete(chats[i]) }
    }
}

private struct ChatRow: View {
    let chat: Chat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: chat.sourcePlatform.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(chat.title)
                    .font(.headline)
            }
            if !chat.socialPostContent.isEmpty {
                Text(chat.socialPostContent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(chat.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
