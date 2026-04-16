import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let chat: Chat
    let topic: Topic

    @State private var viewModel: ChatViewModel
    @State private var hasInitialized = false   // prevents re-init on every onAppear

    init(chat: Chat, topic: Topic) {
        self.chat = chat
        self.topic = topic
        _viewModel = State(initialValue: ChatViewModel(llmService: MockLLMService()))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !chat.socialPostContent.isEmpty {
                ContextBanner(chat: chat, topic: topic)
                Divider()
            }

            messagesScrollView
            Divider()
            if !topic.link.isEmpty {
                LinkCopyBar(link: topic.link)
                Divider()
            }
            quickActionsBar
            inputBar
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            viewModel = ChatViewModel(llmService: appState.llmService)
            viewModel.autoGenerateFirstDM(chat: chat, topic: topic, context: modelContext)
        }
        .onDisappear {
            viewModel.cancelGeneration()
        }
    }

    // MARK: - Empty state

    private var noModelEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No model loaded")
                .font(.headline)
            Text("Go to the Models tab to download a local AI model. Once loaded, come back here and tap Generate.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Generate DM") {
                viewModel.autoGenerateFirstDM(chat: chat, topic: topic, context: modelContext)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appState.isModelLoaded)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if chat.sortedMessages.isEmpty && !viewModel.isGenerating && !appState.isModelLoaded {
                        noModelEmptyState
                    }
                    ForEach(chat.sortedMessages) { message in
                        MessageBubble(message: message, platform: chat.sourcePlatform)
                            .id(message.id)
                    }
                    if viewModel.isGenerating && viewModel.streamingBuffer.isEmpty {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("typing")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
            }
            .onChange(of: chat.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: viewModel.isGenerating)  { _, _ in scrollToBottom(proxy) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - Quick-action chips

    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QuickAction.allCases) { action in
                    Button(action.label) {
                        viewModel.send(
                            userText: action.prompt,
                            chat: chat,
                            topic: topic,
                            context: modelContext
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(action.tint)
                    .controlSize(.small)
                    .disabled(viewModel.isGenerating)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Input bar

    @ViewBuilder
    private var inputBar: some View {
        if let err = viewModel.errorMessage {
            Text(err)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal)
                .padding(.top, 4)
        }

        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask for a variation, adjust tone…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .lineLimit(1...5)

            Button {
                if viewModel.isGenerating {
                    viewModel.cancelGeneration()
                } else {
                    let text = viewModel.inputText
                    viewModel.send(userText: text, chat: chat, topic: topic, context: modelContext)
                }
            } label: {
                Image(systemName: viewModel.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        viewModel.isGenerating
                            ? .red
                            : (viewModel.inputText.isEmpty ? .secondary : .blue)
                    )
            }
            .disabled(!viewModel.isGenerating && viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Quick Actions

private enum QuickAction: String, CaseIterable, Identifiable {
    case tryAgain         = "try_again"
    case shorter          = "shorter"
    case moreCasual       = "more_casual"
    case moreProfessional = "more_professional"
    case addQuestion      = "add_question"
    case lessSalesy       = "less_salesy"
    case moreEmpathetic   = "more_empathetic"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tryAgain:           return "↺ Try again"
        case .shorter:            return "↓ Shorter"
        case .moreCasual:         return "More casual"
        case .moreProfessional:   return "More professional"
        case .addQuestion:        return "Add a question"
        case .lessSalesy:         return "Less salesy"
        case .moreEmpathetic:     return "More empathetic"
        }
    }

    var prompt: String {
        switch self {
        case .tryAgain:
            return "Generate a completely different DM for this person — different opener, different angle, different structure."
        case .shorter:
            return "Rewrite the DM but make it shorter. Cut anything that isn't doing real work."
        case .moreCasual:
            return "Rewrite the DM with a more casual, relaxed tone — like you're texting someone you kind of know."
        case .moreProfessional:
            return "Rewrite the DM with a more professional, peer-to-peer tone. Warm but composed."
        case .addQuestion:
            return "Rewrite the DM and close with a genuine question that invites a reply — not a yes/no, something open."
        case .lessSalesy:
            return "Rewrite the DM to be less salesy. Focus on their situation and your shared experience, not the product."
        case .moreEmpathetic:
            return "Rewrite the DM to lead with more empathy — acknowledge what they're going through before anything else."
        }
    }

    var tint: Color {
        switch self {
        case .tryAgain:           return .orange
        case .shorter:            return .blue
        case .moreCasual:         return .green
        case .moreProfessional:   return .indigo
        case .addQuestion:        return .purple
        case .lessSalesy:         return .teal
        case .moreEmpathetic:     return .pink
        }
    }
}

// MARK: - Context Banner

private struct ContextBanner: View {
    let chat: Chat
    let topic: Topic

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                Label(chat.sourcePlatform.rawValue, systemImage: chat.sourcePlatform.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(chat.socialPostContent)
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Divider()

                Label("Promoting: \(topic.promotionDescription)", systemImage: "megaphone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        } label: {
            Label("Chat Context", systemImage: "info.circle")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }
}

// MARK: - Link Copy Bar

private struct LinkCopyBar: View {
    let link: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(link)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIPasteboard.general.string = link
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            } label: {
                Text(copied ? "Copied!" : "Copy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(copied ? .green : .blue)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: copied)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(.systemGray6))
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(phase ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { phase = true }
    }
}
