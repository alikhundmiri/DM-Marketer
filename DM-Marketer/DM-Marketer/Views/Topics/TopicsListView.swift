import SwiftUI
import SwiftData

struct TopicsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Topic.createdAt, order: .reverse) private var topics: [Topic]

    @State private var showingNewTopic = false

    var body: some View {
        NavigationStack {
            Group {
                if topics.isEmpty {
                    scrollableEmptyState
                } else {
                    topicList
                }
            }
            .navigationTitle("ColdFlow")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTopic = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.cfCyan)
                    }
                }
            }
            .sheet(isPresented: $showingNewTopic) {
                TopicFormView()
            }
        }
    }

    // MARK: - Empty state

    private var scrollableEmptyState: some View {
        ScrollView {
            MascotEmptyState(
                headline: "Flow starts here",
                subheadline: "Create a topic for each product or campaign. Your AI writes the DM, you send the flow.",
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
