import SwiftUI

// MARK: - Parsed message (splits <think>…</think> from the actual DM)

private struct ParsedMessage {
    let thinking: String?           // content inside <think>…</think>, nil if none
    let response: String            // the DM text — empty while still thinking
    let isThinkingInProgress: Bool  // streaming and haven't hit </think> yet
}

private func parse(_ content: String, isStreaming: Bool) -> ParsedMessage {
    let openTag  = "<think>"
    let closeTag = "</think>"

    guard content.hasPrefix(openTag) || content.hasPrefix("<think>\n") else {
        return ParsedMessage(thinking: nil, response: content, isThinkingInProgress: false)
    }

    let afterOpen = String(content.dropFirst(openTag.count))

    if let closeRange = afterOpen.range(of: closeTag) {
        let thinking = String(afterOpen[..<closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let response = String(afterOpen[closeRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedMessage(thinking: thinking, response: response, isThinkingInProgress: false)
    }

    // No closing tag yet — still thinking
    return ParsedMessage(
        thinking: afterOpen.trimmingCharacters(in: .whitespacesAndNewlines),
        response: "",
        isThinkingInProgress: isStreaming
    )
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: Message
    let platform: SourcePlatform

    @State private var copied = false
    @State private var showingEdit = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        let parsed = parse(message.content, isStreaming: message.isStreaming)

        HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {

                // Thinking bubble — only for assistant messages with <think> content
                if !isUser, let thinking = parsed.thinking {
                    ThinkingBubble(content: thinking, inProgress: parsed.isThinkingInProgress)
                }

                // Main bubble — hide when thinking is still in progress and response is empty
                if !parsed.isThinkingInProgress || !parsed.response.isEmpty {
                    let displayText = isUser ? message.content : parsed.response
                    let showBlank  = displayText.isEmpty && message.isStreaming

                    Text(showBlank ? " " : displayText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background {
                            if isUser {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(LinearGradient.cfPrimary)
                            } else {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(.systemGray5))
                            }
                        }
                        .foregroundStyle(isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            if message.isStreaming && !parsed.isThinkingInProgress {
                                BlinkingCursor().padding(6)
                            }
                        }
                        .onTapGesture(count: 2) {
                            guard !message.isStreaming, !displayText.isEmpty else { return }
                            copy(displayText)
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            guard !message.isStreaming, !displayText.isEmpty else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showingEdit = true
                        }
                        .overlay(alignment: .top) {
                            if copied {
                                Text("Copied!")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .transition(.scale.combined(with: .opacity))
                                    .offset(y: -28)
                            }
                        }
                        .animation(.spring(duration: 0.25), value: copied)

                    // Footer: char count + copy (assistant only, after streaming)
                    if !isUser && !message.isStreaming && !parsed.response.isEmpty {
                        HStack(spacing: 12) {
                            charCountBadge(for: parsed.response)

                            Button { copy(parsed.response) } label: {
                                Label(
                                    copied ? "Copied!" : "Copy DM",
                                    systemImage: copied ? "checkmark" : "doc.on.doc"
                                )
                                .font(.caption)
                                .foregroundStyle(copied ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 10)
        .sheet(isPresented: $showingEdit) {
            let editText = isUser ? message.content : parse(message.content, isStreaming: false).response
            MessageEditSheet(content: editText)
        }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }

    @ViewBuilder
    private func charCountBadge(for text: String) -> some View {
        let limit = platform.characterTarget
        let count = text.count
        let over  = count > limit
        let close = !over && count > Int(Double(limit) * 0.9)

        HStack(spacing: 2) {
            Image(systemName: over ? "exclamationmark.circle" : "character.cursor.ibeam")
                .font(.caption2)
            Text("\(count)/\(limit)")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(over ? .red : close ? .orange : .secondary)
    }
}

// MARK: - Thinking Bubble

private struct ThinkingBubble: View {
    let content: String
    let inProgress: Bool

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button {
                guard !inProgress else { return }
                withAnimation(.spring(duration: 0.28, bounce: 0.1)) { expanded.toggle() }
            } label: {
                HStack(spacing: 7) {
                    if inProgress {
                        ThinkingDotsView()
                    } else {
                        Image(systemName: "brain")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                    Text(inProgress ? "Thinking…" : "Reasoning")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(inProgress ? Color.secondary : Color.purple)

                    if !inProgress {
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Expandable reasoning text
            if expanded && !content.isEmpty {
                Divider().padding(.horizontal, 8)
                ScrollView {
                    Text(content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 180)
            }
        }
        .background(Color.purple.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.purple.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Thinking dots (inline, compact wave for ThinkingBubble header)

private struct ThinkingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.purple.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .offset(y: animating ? -3 : 0)
                    .animation(
                        .easeInOut(duration: 0.38)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.12),
                        value: animating
                    )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { animating = true }
        }
    }
}

// MARK: - Message Edit Sheet

private struct MessageEditSheet: View {
    let content: String
    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(content: String) {
        self.content = content
        _text = State(initialValue: content)
    }

    var body: some View {
        NavigationStack {
            SelectableTextView(text: $text)
                .padding(12)
                .navigationTitle("Edit / Copy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            UIPasteboard.general.string = text
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// UITextView wrapper that selects all text on first appear.
private struct SelectableTextView: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.isEditable = true
        tv.isSelectable = true
        tv.delegate = context.coordinator
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        if context.coordinator.needsInitialSelection {
            context.coordinator.needsInitialSelection = false
            DispatchQueue.main.async { uiView.selectAll(nil) }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView
        var needsInitialSelection = true
        init(_ parent: SelectableTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}

// MARK: - Blinking Cursor

private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.secondary)
            .frame(width: 2, height: 14)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
