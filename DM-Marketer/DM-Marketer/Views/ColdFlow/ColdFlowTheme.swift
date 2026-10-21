import SwiftUI

// MARK: - Brand colors

extension Color {
    /// #FF2D4B — lipstick red. CTAs, active states, accents.
    static let cfLip = Color(red: 255 / 255, green: 45 / 255, blue: 75 / 255)
    /// #E0267F — berry. Deeper end of the brand gradient.
    static let cfBerry = Color(red: 224 / 255, green: 38 / 255, blue: 127 / 255)
    /// #8F6BFF — lilac. The icon's background; used for secondary marks.
    static let cfLilac = Color(red: 143 / 255, green: 107 / 255, blue: 255 / 255)
    /// Light lilac tint for backgrounds and cards.
    static let cfSurface = Color(red: 0.97, green: 0.95, blue: 1.0)
}

// MARK: - Gradients

extension LinearGradient {
    /// Primary brand gradient — lipstick red top-left to berry bottom-right.
    static let cfPrimary = LinearGradient(
        stops: [
            .init(color: .cfLip, location: 0),
            .init(color: .cfBerry, location: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Vertical flow gradient (for tall elements like bubbles).
    static let cfFlow = LinearGradient(
        stops: [
            .init(color: .cfLip, location: 0),
            .init(color: .cfBerry, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Shape helpers

extension View {
    /// Pill shape with the SlydeBack gradient background.
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
                .shadow(color: Color.cfLip.opacity(0.08), radius: 12, y: 4)
        )
    }
}
