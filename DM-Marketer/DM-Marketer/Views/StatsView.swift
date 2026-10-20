import SwiftUI

/// What the app has counted on this phone. Testers copy it and send it; nothing is uploaded.
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var report = UsageStats.report()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(report).font(.callout.monospaced())
                } footer: {
                    Text("Counted on this phone only. Nothing is sent anywhere unless you copy this and send it to us.")
                }
                Section {
                    Button(copied ? "Copied" : "Copy stats") {
                        UIPasteboard.general.string = report
                        copied = true
                    }
                }
            }
            .navigationTitle("Your stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
