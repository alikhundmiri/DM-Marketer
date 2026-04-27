import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case topics, models
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<LLMModel> { $0.isDefault == true && $0.isDownloaded == true })
    private var defaultModels: [LLMModel]

    @State private var selectedTab: AppTab = .topics

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content — reserve space at the bottom so scroll views clear the tab bar
            Group {
                switch selectedTab {
                case .topics: TopicsListView()
                case .models: ModelsView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 90)
            }

            // Floating ColdFlow tab bar
            ColdFlowTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: pendingShareBinding) { share in
            PendingShareTopicPickerView(share: share.share)
        }
        .task(id: defaultModels.first?.id) {
            guard let model = defaultModels.first, let url = model.localURL else { return }
            await appState.loadModel(at: url, displayName: model.displayName)
        }
    }

    private var pendingShareBinding: Binding<IdentifiablePendingShare?> {
        Binding(
            get: { appState.pendingShare.map { IdentifiablePendingShare(share: $0) } },
            set: { appState.pendingShare = $0?.share }
        )
    }
}

// MARK: - ColdFlow floating tab bar

private struct ColdFlowTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 4) {
            FlowTab(tab: .topics, selected: $selected,
                    icon: "folder.fill",  label: "Topics")
            FlowTab(tab: .models, selected: $selected,
                    icon: "cpu.fill",     label: "Models")
        }
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.cfCyan.opacity(0.4), Color.cfBlue.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.cfCyan.opacity(0.22), radius: 20, y: 6)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 48)
        .padding(.bottom, 20)
    }
}

private struct FlowTab: View {
    let tab: AppTab
    @Binding var selected: AppTab
    let icon: String
    let label: String

    private var isSelected: Bool { selected == tab }

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.15)) { selected = tab }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .background {
                if isSelected {
                    Capsule().fill(LinearGradient.cfPrimary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Identifiable wrapper for PendingShare sheet

struct IdentifiablePendingShare: Identifiable {
    let id = UUID()
    var share: PendingShare
}
