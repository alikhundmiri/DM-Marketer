import SwiftUI
import SwiftData

/// Replies the user has copied from the share sheet. Mark the ones that got an answer.
struct EngagementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \Engagement.createdAt, order: .reverse) private var engagements: [Engagement]

    var body: some View {
        Group {
            if engagements.isEmpty {
                ContentUnavailableView(
                    "No replies yet",
                    systemImage: "tray",
                    description: Text("Replies you copy from the share sheet show up here. Tap \"Got a reply\" when they answer.")
                )
            } else {
                List {
                    Section {
                        ForEach(engagements) { row($0) }
                            .onDelete { offsets in
                                for i in offsets { modelContext.delete(engagements[i]) }
                            }
                    } footer: {
                        let replied = engagements.filter(\.gotReply).count
                        Text("\(replied) of \(engagements.count) got a reply")
                    }
                }
            }
        }
        .navigationTitle("Replies")
    }

    private func row(_ e: Engagement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(e.handle.isEmpty ? "Post" : "@\(e.handle)").font(.headline)
                Text(e.kind).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(e.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
            }
            Text(e.draft).font(.callout).lineLimit(3)
            HStack {
                if let url = URL(string: e.postURL), !e.postURL.isEmpty {
                    Button("Open post") { openURL(url) }
                }
                Spacer()
                Button {
                    e.gotReply.toggle()
                } label: {
                    Label(e.gotReply ? "Got a reply" : "Mark replied",
                          systemImage: e.gotReply ? "checkmark.circle.fill" : "circle")
                }
                .tint(e.gotReply ? .green : .accentColor)
            }
            .font(.footnote)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
