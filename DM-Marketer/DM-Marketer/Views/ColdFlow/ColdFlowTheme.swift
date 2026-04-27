import SwiftUI

// MARK: - Brand colors

extension Color {
    /// #00CED1 — "flow" cyan. CTAs, active states, movement indicators.
    static let cfCyan = Color(red: 0 / 255, green: 206 / 255, blue: 209 / 255)
    /// #0891B2 — trust blue. Stability, background automation.
    static let cfBlue = Color(red: 8 / 255, green: 145 / 255, blue: 178 / 255)
    /// Light tint for backgrounds and cards.
    static let cfSurface = Color(red: 0.96, green: 0.99, blue: 1.0)
}

// MARK: - Gradients

extension LinearGradient {
    /// Primary brand gradient — cyan top-left to blue bottom-right.
    static let cfPrimary = LinearGradient(
        stops: [
            .init(color: .cfCyan, location: 0),
            .init(color: .cfBlue, location: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Vertical flow gradient (for tall elements like bubbles).
    static let cfFlow = LinearGradient(
        stops: [
            .init(color: .cfCyan, location: 0),
            .init(color: .cfBlue, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Shape helpers

extension View {
    /// Pill shape with the ColdFlow gradient background.
    func cfPillBackground(padding h: CGFloat = 14, v: CGFloat = 10) -> some View {
        self
            .padding(.horizontal, h)
            .padding(.vertical, v)
            .background(LinearGradient.cfPrimary, in: Capsule())
            .foregroundStyle(.white)
    }

    /// Subtle tinted card background.
    func cfCard(cornerRadius: CGFloat = 16) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.cfSurface)
                .shadow(color: Color.cfCyan.opacity(0.08), radius: 12, y: 4)
        )
    }
}
