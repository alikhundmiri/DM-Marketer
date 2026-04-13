import SwiftUI
import SwiftData

/// Manual chat creation (no share extension). User pastes the social post themselves.
struct NewChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let topic: Topic
    /// Called with the created chat so the caller can navigate into it immediately.
    var onChatCreated: ((Chat) -> Void)? = nil

    @State private var title = ""
    @State private var socialPostContent = ""
    @State private var selectedPlatform: SourcePlatform = .twitter

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach(SourcePlatform.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.systemImage).tag(p)
                        }
                    }
                } header: { Text("Source Platform") }

                Section {
                    TextField("e.g. @username complaining about X", text: $title)
                } header: { Text("Chat Title") }

                Section {
                    TextEditor(text: $socialPostContent)
                        .frame(minHeight: 120)
                } header: {
                    Text("Their Post or Comment")
                } footer: {
                    Text("Paste the tweet, LinkedIn post, or Reddit comment you want to respond to. Leave empty for a general outreach message.")
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { createChat() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func createChat() {
        let chat = Chat(
            title: title,
            socialPostContent: socialPostContent,
            sourcePlatform: selectedPlatform
        )
        chat.topic = topic
        topic.chats.append(chat)
        modelContext.insert(chat)

        if let onChatCreated {
            onChatCreated(chat)
        } else {
            dismiss()
        }
    }
}
