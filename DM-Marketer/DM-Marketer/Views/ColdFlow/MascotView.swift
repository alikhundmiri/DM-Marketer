import SwiftUI

// MARK: - Droplet mascot

/// Animated ColdFlow droplet mascot. Floats up-and-down and blinks.
struct DropletMascot: View {
    var size: CGFloat = 100
    var animated: Bool = true

    @State private var floating = false
    @State private var blinking = false

    var body: some View {
        ZStack {
            // Soft ground shadow
            Ellipse()
                .fill(Color.cfCyan.opacity(0.18))
                .frame(width: size * 0.65, height: size * 0.1)
                .blur(radius: size * 0.05)
                .offset(y: size * 0.54)
                .scaleEffect(x: floating ? 0.85 : 1.0, anchor: .center)

            // Body
            DropletBodyShape()
                .fill(LinearGradient.cfFlow)
                .frame(width: size * 0.78, height: size)

            // Shimmer highlight (upper-left of body)
            Ellipse()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.42), location: 0),
                            .init(color: .white.opacity(0),    location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.19, height: size * 0.32)
                .rotationEffect(.degrees(-30))
                .offset(x: -size * 0.2, y: -size * 0.2)

            // Face — positioned in the lower half of the droplet
            VStack(spacing: size * 0.05) {
                // Eyes row
                HStack(spacing: size * 0.18) {
                    MascotEye(outerSize: size * 0.15, blinking: blinking)
                    MascotEye(outerSize: size * 0.15, blinking: blinking)
                }
                // Smile
                MascotSmile(width: size * 0.28, height: size * 0.095)
                    .stroke(Color.white,
                            style: StrokeStyle(lineWidth: size * 0.032, lineCap: .round))
            }
            .offset(y: size * 0.2)

            // Blush circles
            HStack(spacing: size * 0.5) {
                Ellipse()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: size * 0.15, height: size * 0.07)
                Ellipse()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: size * 0.15, height: size * 0.07)
            }
            .offset(y: size * 0.32)

            // Sparkle top-right
            SparkleView(size: size * 0.1)
                .offset(x: size * 0.3, y: -size * 0.3)
                .opacity(floating ? 0.8 : 0.3)
        }
        .offset(y: floating ? -size * 0.038 : size * 0.038)
        .animation(
            animated
                ? .easeInOut(duration: 1.9).repeatForever(autoreverses: true)
                : .none,
            value: floating
        )
        .onAppear {
            guard animated else { return }
            floating = true
            scheduleBlink()
        }
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2.5...4.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.10)) { blinking = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.easeInOut(duration: 0.10)) { blinking = false }
                scheduleBlink()
            }
        }
    }
}

// MARK: - Eye

private struct MascotEye: View {
    let outerSize: CGFloat
    let blinking: Bool

    var body: some View {
        ZStack {
            // White of eye
            Ellipse()
                .fill(Color.white)
                .frame(width: outerSize, height: blinking ? outerSize * 0.12 : outerSize * 1.25)

            if !blinking {
                // Pupil
                Circle()
                    .fill(Color.cfBlue)
                    .frame(width: outerSize * 0.65, height: outerSize * 0.65)
                    .offset(x: outerSize * 0.08, y: outerSize * 0.05)

                // Shine dot
                Circle()
                    .fill(Color.white)
                    .frame(width: outerSize * 0.22, height: outerSize * 0.22)
                    .offset(x: -outerSize * 0.08, y: -outerSize * 0.16)
            }
        }
        .animation(.easeInOut(duration: 0.1), value: blinking)
    }
}

// MARK: - Smile

private struct MascotSmile: Shape {
    let width: CGFloat
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: width, y: 0),
            control: CGPoint(x: width / 2, y: height)
        )
        return p
    }
}

// MARK: - Droplet body shape

private struct DropletBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, cx = rect.midX
        var p = Path()
        // Tip at top
        p.move(to: CGPoint(x: cx, y: 0))
        // Right outward curve
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.66),
            control1: CGPoint(x: cx + w * 0.46, y: h * 0.1),
            control2: CGPoint(x: w, y: h * 0.46)
        )
        // Bottom right arc
        p.addQuadCurve(
            to: CGPoint(x: cx, y: h),
            control: CGPoint(x: w, y: h)
        )
        // Bottom left arc
        p.addQuadCurve(
            to: CGPoint(x: 0, y: h * 0.66),
            control: CGPoint(x: 0, y: h)
        )
        // Left inward curve back to tip
        p.addCurve(
            to: CGPoint(x: cx, y: 0),
            control1: CGPoint(x: 0, y: h * 0.46),
            control2: CGPoint(x: cx - w * 0.46, y: h * 0.1)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Sparkle

private struct SparkleView: View {
    let size: CGFloat
    @State private var rotating = false

    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: size * 0.18, height: size * 0.8)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotating ? 180 : 0))
        .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: rotating)
        .onAppear { rotating = true }
    }
}

// MARK: - Empty state wrapper

/// Full empty-state card: mascot + headline + subheadline + optional action.
struct MascotEmptyState: View {
    let headline: String
    let subheadline: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            DropletMascot(size: 110)

            VStack(spacing: 8) {
                Text(headline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cfCyan, .cfBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)

                Text(subheadline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let label = actionLabel, let act = action {
                Button(label, action: act)
                    .cfPillBackground(padding: 20, v: 12)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
