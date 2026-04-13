import SwiftUI
import SwiftData

/// Used for both creating and editing a Topic.
struct TopicFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Pass a topic to edit it; nil to create a new one.
    var topic: Topic? = nil

    @State private var name = ""
    @State private var promotionDescription = ""
    @State private var link = ""

    private var isEditing: Bool { topic != nil }
    private var canSave: Bool { !name.isEmpty && !promotionDescription.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. My iOS App – Indie Devs", text: $name)
                } header: {
                    Text("Topic Name")
                }

                Section {
                    TextEditor(text: $promotionDescription)
                        .frame(minHeight: 100)
                } header: {
                    Text("What You're Promoting")
                } footer: {
                    Text("Describe your product and the problem it solves. The LLM uses this to craft personalized DMs.")
                }

                Section {
                    TextField("https://apps.apple.com/…", text: $link)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Link")
                } footer: {
                    Text("App Store link, landing page, or any URL to include in the DM.")
                }
            }
            .navigationTitle(isEditing ? "Edit Topic" : "New Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: populateIfEditing)
        }
    }

    private func populateIfEditing() {
        guard let topic else { return }
        name = topic.name
        promotionDescription = topic.promotionDescription
        link = topic.link
    }

    private func save() {
        if let topic {
            topic.name = name
            topic.promotionDescription = promotionDescription
            topic.link = link
        } else {
            let newTopic = Topic(name: name, promotionDescription: promotionDescription, link: link)
            modelContext.insert(newTopic)
        }
        dismiss()
    }
}

#Preview {
    TopicFormView()
        .modelContainer(for: Topic.self, inMemory: true)
}
