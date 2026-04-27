import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let chat: Chat
    let topic: Topic

    @State private var viewModel: ChatViewModel
    @State private var hasInitialized = false

    init(chat: Chat, topic: Topic) {
        self.chat = chat
        self.topic = topic
        _viewModel = State(initialValue: ChatViewModel(llmService: MockLLMService()))
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty && appState.isModelLoaded
    }

    var body: some View {
        VStack(spacing: 0) {
            // Context strip (platform + topic)
            if !chat.socialPostContent.isEmpty {
                contextStrip
                Divider()
            }

            // Model status banner
            modelStatusBanner

            // Chat messages
            messagesScrollView

            // Bottom input section
            inputSection
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                viewModel = ChatViewModel(llmService: appState.llmService)
            }
            viewModel.autoGenerateFirstDM(chat: chat, topic: topic, context: modelContext)
        }
        .onChange(of: appState.isModelLoaded) { _, isLoaded in
            guard isLoaded, chat.messages.isEmpty, !viewModel.isGenerating else { return }
            viewModel.autoGenerateFirstDM(chat: chat, topic: topic, context: modelContext)
        }
        .onChange(of: appState.isModelLoading) { _, isLoading in
            guard !isLoading, appState.isModelLoaded,
                  chat.messages.isEmpty, !viewModel.isGenerating else { return }
            viewModel.autoGenerateFirstDM(chat: chat, topic: topic, context: modelContext)
        }
        .onDisappear {
            viewModel.cancelGeneration()
        }
    }

    // MARK: - Context strip

    private var contextStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: chat.sourcePlatform.systemImage)
                .font(.caption.weight(.semibold))
            Text(chat.sourcePlatform.rawValue)
                .font(.caption.weight(.medium))
            Text("·")
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))
            Image(systemName: "megaphone.fill")
                .font(.caption2)
                .foregroundStyle(Color(.tertiaryLabel))
            Text(topic.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(.systemGray6))
    }

    // MARK: - Model status banner

    @ViewBuilder
    private var modelStatusBanner: some View {
        if !chat.sortedMessages.isEmpty {
            if appState.isModelLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(.secondary)
                    Text("Loading \(appState.loadingModelName ?? "model")…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(.systemGray6))
                Divider()
            } else if !appState.isModelLoaded {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                    Text("Model not loaded")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Button("Reload") {
                        Task { await appState.reloadLastModel() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(colors: [.cfCyan, .cfBlue],
                                       startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.orange.opacity(0.07))
                Divider()
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyStateView: some View {
        if appState.isModelLoading {
            VStack(spacing: 16) {
                DropletMascot(size: 90)
                Text("Loading \(appState.loadingModelName ?? "model")…")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(colors: [.cfCyan, .cfBlue],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                ProgressView()
                    .tint(.cfCyan)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        } else if appState.isModelLoaded {
            MascotEmptyState(
                headline: "Ready to flow",
                subheadline: "Your smol AI is loaded and ready to write a cold DM.",
                actionLabel: "Generate DM",
                action: {
                    viewModel.autoGenerateFirstDM(chat: chat, topic: topic, context: modelContext)
                }
            )
        } else {
            MascotEmptyState(
                headline: "No model loaded",
                subheadline: appState.loadModelError
                    ?? "Go to the Models tab and download a model to get started."
            )
        }
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    // Social post shown as a received bubble at the top
                    if !chat.socialPostContent.isEmpty {
                        ContextPostBubble(platform: chat.sourcePlatform,
                                          content: chat.socialPostContent)
                            .id("context-post")
                    }

                    if chat.sortedMessages.isEmpty && !viewModel.isGenerating {
                        emptyStateView
                    }

                    ForEach(chat.sortedMessages) { message in
                        MessageBubble(message: message, platform: chat.sourcePlatform)
                            .id(message.id)
                    }

                    // Typing indicator while waiting for first token
                    if viewModel.isGenerating && viewModel.streamingBuffer.isEmpty {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .id("typing")
                    }

                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.top, 12)
                .padding(.bottom, 4)
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

    // MARK: - Bottom input section

    private var inputSection: some View {
        VStack(spacing: 0) {
            Divider()

            // Link copy bar
            if !topic.link.isEmpty {
                LinkCopyBar(link: topic.link)
                Divider()
            }

            // Quick action chips
            quickActionsBar

            Divider()

            // Error message
            if let err = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(err)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 2)
            }

            // Text input + send button
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Adjust tone, try a variation…", text: $viewModel.inputText, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                sendStopButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .padding(.bottom, 2)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Quick actions

    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QuickAction.allCases) { action in
                    Button {
                        viewModel.send(userText: action.prompt,
                                       chat: chat, topic: topic, context: modelContext)
                    } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(action.tint.opacity(0.10),
                                        in: Capsule())
                            .foregroundStyle(action.tint)
                            .overlay(Capsule().strokeBorder(action.tint.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isGenerating || !appState.isModelLoaded)
                    .opacity((viewModel.isGenerating || !appState.isModelLoaded) ? 0.4 : 1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Send / Stop button

    private var sendStopButton: some View {
        Button {
            if viewModel.isGenerating {
                viewModel.cancelGeneration()
            } else {
                let text = viewModel.inputText
                viewModel.send(userText: text, chat: chat, topic: topic, context: modelContext)
            }
        } label: {
            Image(systemName: viewModel.isGenerating ? "stop.fill" : "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background {
                    if viewModel.isGenerating {
                        Circle().fill(Color.red)
                    } else if canSend {
                        Circle().fill(LinearGradient.cfPrimary)
                    } else {
                        Circle().fill(Color(.systemGray4))
                    }
                }
                .animation(.spring(duration: 0.2), value: viewModel.isGenerating)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isGenerating && !canSend)
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
        case .tryAgain:           return "Try again"
        case .shorter:            return "Shorter"
        case .moreCasual:         return "Casual"
        case .moreProfessional:   return "Professional"
        case .addQuestion:        return "Add question"
        case .lessSalesy:         return "Less salesy"
        case .moreEmpathetic:     return "Empathetic"
        }
    }

    var icon: String {
        switch self {
        case .tryAgain:           return "arrow.counterclockwise"
        case .shorter:            return "arrow.down.right.and.arrow.up.left"
        case .moreCasual:         return "face.smiling"
        case .moreProfessional:   return "building.2"
        case .addQuestion:        return "questionmark.bubble"
        case .lessSalesy:         return "tag.slash"
        case .moreEmpathetic:     return "heart.fill"
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

// MARK: - Context Post Bubble

private struct ContextPostBubble: View {
    let platform: SourcePlatform
    let content: String

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: platform.systemImage)
                        .font(.caption2.weight(.semibold))
                    Text("Their \(platform.rawValue) post")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)

                Text(content)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 10)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.15).delay(0.05)) {
                appeared = true
            }
        }
    }
}

// MARK: - Link Copy Bar

private struct LinkCopyBar: View {
    let link: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(link)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIPasteboard.general.string = link
                withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeInOut(duration: 0.2)) { copied = false }
                }
            } label: {
                Text(copied ? "Copied!" : "Copy link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(copied ? .green : .accentColor)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: copied)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(white: 0.52))
                    .frame(width: 9, height: 9)
                    .offset(y: animating ? -5 : 0)
                    .animation(
                        .easeInOut(duration: 0.42)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.14),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { animating = true }
        }
    }
}
