import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<LLMModel> { $0.isDefault == true && $0.isDownloaded == true })
    private var defaultModels: [LLMModel]

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
        .task(id: defaultModels.first?.id) {
            guard let model = defaultModels.first, let url = model.localURL else { return }
            await appState.loadModel(at: url, displayName: model.displayName)
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
