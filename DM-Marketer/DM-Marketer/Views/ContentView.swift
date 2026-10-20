import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case topics
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @Query private var topics: [Topic]

    @State private var selectedTab: AppTab = .topics

    var body: some View {
        if let reason = appState.unavailableReason {
            UnsupportedDeviceView(reason: reason)
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Content — reserve space at the bottom so scroll views clear the tab bar
            Group {
                switch selectedTab {
                case .topics: TopicsListView()
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: pendingShareBinding) { share in
            PendingShareTopicPickerView(share: share)
        }
        // The Share Extension can't open the app, so it leaves the post in the App Group
        // and posts a notification. Whenever we become active, pick it up.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, let context = PendingShareStore.take() else { return }
            appState.pendingShare = PendingShare(context)
        }
        // Keep the Share Extension's copy of the user's Topics current.
        .task(id: topicsSnapshot) { SharedTopicStore.save(topicsSnapshot) }
    }

    private var topicsSnapshot: [SharedTopic] {
        topics.sorted { $0.createdAt < $1.createdAt }.map {
            SharedTopic(id: $0.id, name: $0.name, promotionDescription: $0.promotionDescription, link: $0.link)
        }
    }

    private var pendingShareBinding: Binding<PendingShare?> {
        Binding(
            get: { appState.pendingShare },
            set: { appState.pendingShare = $0 }
        )
    }
}
