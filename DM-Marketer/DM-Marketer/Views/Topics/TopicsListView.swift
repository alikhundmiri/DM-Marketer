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
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Topics")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewTopic = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTopic) {
                TopicFormView()
            }
        }
    }

    private var list: some View {
        List {
            ForEach(topics) { topic in
                NavigationLink(destination: TopicDetailView(topic: topic)) {
                    TopicRow(topic: topic)
                }
            }
            .onDelete(perform: deleteTopics)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Topics", systemImage: "folder.badge.plus")
        } description: {
            Text("Create a topic for each product or campaign you want to promote.")
        } actions: {
            Button("Create Topic") { showingNewTopic = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func deleteTopics(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(topics[i]) }
    }
}

private struct TopicRow: View {
    let topic: Topic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(topic.name)
                .font(.headline)
            Text(topic.promotionDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Label("\(topic.chats.count) chats", systemImage: "bubble.left")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
