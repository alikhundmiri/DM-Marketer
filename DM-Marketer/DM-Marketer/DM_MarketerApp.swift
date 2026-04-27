import SwiftUI
import SwiftData
import UIKit

// MARK: - AppDelegate

/// Receives the background URLSession completion handler from iOS.
/// Without this, iOS throttles or cancels future background downloads.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        ModelDownloadService.shared.backgroundCompletionHandler = completionHandler
    }
}

// MARK: - App

@main
struct DM_MarketerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // @State is correct for @Observable objects (not @StateObject, which is for ObservableObject)
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Topic.self,
            Chat.self,
            Message.self,
            LLMModel.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .task {
                    ModelDownloadService.shared.reconnect()
                }
                // Fix 2: free GPU/RAM immediately when iOS signals memory pressure
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didReceiveMemoryWarningNotification)
                ) { _ in
                    print("[Memory] Warning received — unloading model")
                    appState.unloadModel()
                }
                // Fix 3: unload when backgrounded so the model doesn't sit in GPU memory
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didEnterBackgroundNotification)
                ) { _ in
                    print("[Lifecycle] App backgrounded — unloading model")
                    appState.unloadModel()
                }
                // Fix 3: reload when foregrounded so inference is ready again
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    print("[Lifecycle] App foregrounded — reloading model")
                    Task { await appState.reloadLastModel() }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Handles dmmarketer://chat?id=<UUID> and dmmarketer://share?text=...&url=...&platform=...
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "dmmarketer",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }

        switch url.host {
        case "chat":
            if let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let uuid = UUID(uuidString: idString) {
                appState.pendingChatID = uuid
            }
        case "share":
            let items = components.queryItems ?? []
            let text     = items.first(where: { $0.name == "text"     })?.value ?? ""
            let sourceURL = items.first(where: { $0.name == "url"     })?.value ?? ""
            let platform = items.first(where: { $0.name == "platform" })?.value ?? "other"
            appState.pendingShare = PendingShare(text: text, url: sourceURL, platform: platform)
        default:
            break
        }
    }
}
