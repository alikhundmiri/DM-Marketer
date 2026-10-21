import SwiftUI

/// The user's voice card: a few lines on how they write. Sent with every draft.
struct VoiceCardView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(VoiceCardStore.key, store: VoiceCardStore.defaults) private var voice = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $voice)
                        .frame(minHeight: 160)
                        .onChange(of: voice) { _, new in
                            if new.count > ContextBudget.voiceCardLimit {
                                voice = String(new.prefix(ContextBudget.voiceCardLimit))
                            }
                        }
                } header: {
                    Text("How you write")
                } footer: {
                    Text("\(voice.count)/\(ContextBudget.voiceCardLimit). Tone, habits, and one or two lines you've really written. Example: \"Casual, lowercase, short sentences. Dry humour. I never say 'reach out'. e.g. 'ha, same. took me three tries to get invoices matching too.'\" Stays on this phone.")
                }
            }
            .navigationTitle("Your voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
