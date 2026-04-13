import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            TopicsListView()
                .tabItem { Label("Topics", systemImage: "folder.fill") }

            ModelsView()
                .tabItem { Label("Models", systemImage: "cpu") }
        }
        .sheet(item: pendingShareBinding) { share in
            PendingShareTopicPickerView(share: share.share)
        }
    }

    /// Bridges AppState.pendingShare (optional struct) into an Identifiable binding for .sheet(item:).
    private var pendingShareBinding: Binding<IdentifiablePendingShare?> {
        Binding(
            get: {
                appState.pendingShare.map { IdentifiablePendingShare(share: $0) }
            },
            set: { newValue in
                appState.pendingShare = newValue?.share
            }
        )
    }
}

/// Thin Identifiable wrapper so PendingShare (a plain struct) works with .sheet(item:).
struct IdentifiablePendingShare: Identifiable {
    let id = UUID()
    var share: PendingShare
}
