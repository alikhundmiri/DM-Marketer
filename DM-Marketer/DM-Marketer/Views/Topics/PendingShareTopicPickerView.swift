import SwiftUI
import SwiftData

/// Shown as a sheet when the app is opened via the Share Extension.
/// The user picks which topic to attach the shared post to, then a Chat is
/// created and the app navigates directly into ChatView.
struct PendingShareTopicPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let share: PendingShare

    @Query(sort: \Topic.createdAt, order: .reverse) private var topics: [Topic]

    /// Non-nil once a chat is created so we can navigate into it.
    @State private var createdChat: Chat?
    @State private var selectedTopic: Topic?

    private var detectedPlatform: SourcePlatform {
        switch share.platform {
        case "Twitter / X": return .twitter
        case "LinkedIn":    return .linkedin
        case "Reddit":      return .reddit
        default:            return .other
        }
    }

    /// Generate a short title from the first few words of the shared text.
    private var autoTitle: String {
        let words = share.text.split(separator: " ").prefix(5)
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? "Shared post" : joined
    }

    var body: some View {
        NavigationStack {
            Group {
                if topics.isEmpty {
                    emptyTopicsPlaceholder
                } else {
                    List(topics) { topic in
                        Button {
                            createChat(for: topic)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if !topic.promotionDescription.isEmpty {
                                    Text(topic.promotionDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Choose a Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.pendingShare = nil
                        dismiss()
                    }
                }
            }
            // Navigate into the new chat once it's been created
            .navigationDestination(item: $createdChat) { chat in
                ChatView(chat: chat, topic: chat.topic!)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private func createChat(for topic: Topic) {
        let chat = Chat(
            title: String(autoTitle.prefix(60)),
            socialPostContent: share.text,
            socialPostURL: share.url,
            sourcePlatform: detectedPlatform
        )
        chat.topic = topic
        topic.chats.append(chat)
        modelContext.insert(chat)

        // Clear the pending share before navigating so the sheet doesn't re-appear
        appState.pendingShare = nil
        createdChat = chat
    }

    private var emptyTopicsPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No topics yet")
                .font(.title3.weight(.semibold))
            Text("Create a topic first from the Topics tab, then share posts into it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
