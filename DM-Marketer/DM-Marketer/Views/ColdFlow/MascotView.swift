import SwiftUI

// MARK: - SVG path shape

/// Draws an SVG path (absolute M, C, Q, H, V, Z only) from the 1024-unit icon artwork,
/// scaled into whatever rect it's given. Keeps the in-app mascot identical to the app icon.
private struct SVGShape: Shape {
    let d: String

    /// The artwork's centre of mass is (512, 616); this window centres the mouth and leaves room for the yap marks.
    static let window = CGRect(x: 40, y: 144, width: 944, height: 944)

    func path(in rect: CGRect) -> Path {
        let tokens = Self.tokens(d)
        var path = Path()
        var i = 0
        var current = CGPoint.zero
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + (x - Self.window.minX) / Self.window.width * rect.width,
                    y: rect.minY + (y - Self.window.minY) / Self.window.height * rect.height)
        }
        func num() -> Double { defer { i += 1 }; return Double(tokens[i]) ?? 0 }
        var raw = (x: 0.0, y: 0.0)
        while i < tokens.count {
            let cmd = tokens[i]; i += 1
            switch cmd {
            case "M": raw = (num(), num()); current = point(raw.x, raw.y); path.move(to: current)
            case "C":
                let c1 = point(num(), num()), c2 = point(num(), num())
                raw = (num(), num()); current = point(raw.x, raw.y)
                path.addCurve(to: current, control1: c1, control2: c2)
            case "Q":
                let c = point(num(), num())
                raw = (num(), num()); current = point(raw.x, raw.y)
                path.addQuadCurve(to: current, control: c)
            case "H": raw.x = num(); current = point(raw.x, raw.y); path.addLine(to: current)
            case "V": raw.y = num(); current = point(raw.x, raw.y); path.addLine(to: current)
            case "Z": path.closeSubpath()
            default: break
            }
        }
        return path
    }

    private static func tokens(_ d: String) -> [String] {
        var out: [String] = [], number = ""
        for ch in d {
            if ch.isLetter {
                if !number.isEmpty { out.append(number); number = "" }
                out.append(String(ch))
            } else if ch == " " || ch == "," {
                if !number.isEmpty { out.append(number); number = "" }
            } else {
                number.append(ch)
            }
        }
        if !number.isEmpty { out.append(number) }
        return out
    }
}

// MARK: - Yap mascot

/// The SlydeBack mouth: red lips, mid-yap. Same artwork as the app icon.
struct YapMascot: View {
    var size: CGFloat = 100
    var animated: Bool = true

    @State private var yapping = false

    private static let upper = "M192 540 C250 420 360 340 440 372 C480 388 500 410 512 410 C524 410 544 388 584 372 C664 340 774 420 832 540 C760 500 640 480 512 480 C384 480 264 500 192 540 Z"
    private static let lower = "M192 540 C234 700 364 770 512 770 C660 770 790 700 832 540 C800 770 660 860 512 860 C364 860 224 770 192 540 Z"
    private static let mouth = "M192 540 C264 500 384 480 512 480 C640 480 760 500 832 540 C790 700 660 770 512 770 C364 770 234 700 192 540 Z"
    private static let tongue = "M360 700 C380 590 644 590 664 700 C640 760 384 760 360 700 Z"
    private static let teeth = "M270 470 H754 V580 Q754 600 734 600 H290 Q270 600 270 580 Z"

    private var line: CGFloat { size * 28 / 944 }
    private let ink = Color(red: 0x2A / 255, green: 0x0A / 255, blue: 0x1E / 255)

    var body: some View {
        ZStack {
            SVGShape(d: Self.mouth).fill(Color(red: 0x4A / 255, green: 0x0F / 255, blue: 0x24 / 255))
            ZStack {
                SVGShape(d: Self.tongue).fill(Color(red: 1, green: 0x7B / 255, blue: 0xA9 / 255))
                SVGShape(d: Self.teeth).fill(.white)
                SVGShape(d: "M391 480 V600 M512 480 V600 M633 480 V600")
                    .stroke(ink.opacity(0.35), lineWidth: line * 0.25)
            }
            .clipShape(SVGShape(d: Self.mouth))
            SVGShape(d: Self.mouth).stroke(ink, style: StrokeStyle(lineWidth: line, lineJoin: .round))
            SVGShape(d: Self.lower).fill(Color.cfLip)
            SVGShape(d: Self.lower).stroke(ink, style: StrokeStyle(lineWidth: line, lineJoin: .round))
            SVGShape(d: Self.upper).fill(Color.cfLip)
            SVGShape(d: Self.upper).stroke(ink, style: StrokeStyle(lineWidth: line, lineJoin: .round))
            // Lipstick shine
            SVGShape(d: "M290 440 Q330 405 372 425 Q330 445 290 440 Z").fill(.white.opacity(0.9))
            SVGShape(d: "M520 815 Q590 800 668 812 Q590 830 520 815 Z").fill(.white.opacity(0.8))
            // Yap marks
            ForEach(0..<2, id: \.self) { side in
                SVGShape(d: side == 0
                         ? "M150 280 Q110 250 120 200 M104 350 Q54 330 56 270"
                         : "M874 280 Q914 250 904 200 M920 350 Q970 330 968 270")
                    .stroke(Color.cfLilac, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .opacity(yapping ? 1 : 0.35)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(x: 1, y: yapping ? 1.05 : 0.97, anchor: .center)
        .rotationEffect(.degrees(yapping ? 1.5 : -1.5))
        .animation(animated ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true) : .none, value: yapping)
        .onAppear { if animated { yapping = true } }
        .accessibilityHidden(true)
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
            YapMascot(size: 190)

            VStack(spacing: 8) {
                Text(headline)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cfLip, .cfBerry],
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
                    .font(.subheadline.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
