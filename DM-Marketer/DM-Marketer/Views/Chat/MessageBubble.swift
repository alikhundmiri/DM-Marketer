import SwiftUI

struct MessageBubble: View {
    let message: Message
    let platform: SourcePlatform

    @State private var copied = false
    @State private var showingEdit = false

    private var isUser: Bool { message.role == .user }
    private var charCount: Int { message.content.count }
    private var charLimit: Int { platform.characterTarget }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // ── Bubble ───────────────────────────────────────────────
                Text(message.content.isEmpty && message.isStreaming ? " " : message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(alignment: .bottomTrailing) {
                        if message.isStreaming { BlinkingCursor().padding(6) }
                    }
                    // Double-tap → copy whole message
                    .onTapGesture(count: 2) {
                        guard !message.isStreaming, !message.content.isEmpty else { return }
                        copyAll()
                    }
                    // Long-press → editable sheet for partial selection / editing
                    .onLongPressGesture(minimumDuration: 0.4) {
                        guard !message.isStreaming, !message.content.isEmpty else { return }
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

                // ── Footer: char count + copy (assistant only) ───────────
                if !isUser && !message.isStreaming && !message.content.isEmpty {
                    HStack(spacing: 12) {
                        charCountBadge

                        Button(action: copyAll) {
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

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 10)
        .sheet(isPresented: $showingEdit) {
            MessageEditSheet(content: message.content)
        }
    }

    // MARK: - Helpers

    private func copyAll() {
        UIPasteboard.general.string = message.content
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }

    @ViewBuilder
    private var charCountBadge: some View {
        let over  = charCount > charLimit
        let close = !over && charCount > Int(Double(charLimit) * 0.9)

        HStack(spacing: 2) {
            Image(systemName: over ? "exclamationmark.circle" : "character.cursor.ibeam")
                .font(.caption2)
            Text("\(charCount)/\(charLimit)")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(over ? .red : close ? .orange : .secondary)
    }
}

// MARK: - Message Edit Sheet

/// Long-press opens this sheet. UITextView auto-selects all text so the user can
/// copy the whole DM, or drag the handles to select and copy just a portion.
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
/// Lets the user drag selection handles to copy a specific portion.
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

        // Select all text only on the very first layout pass
        if context.coordinator.needsInitialSelection {
            context.coordinator.needsInitialSelection = false
            DispatchQueue.main.async { uiView.selectAll(nil) }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView
        var needsInitialSelection = true

        init(_ parent: SelectableTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
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
