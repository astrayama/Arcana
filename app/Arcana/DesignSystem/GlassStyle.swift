import SwiftUI

// MARK: - Glass panel (`.gp` in the wireframe)

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 18
    var stroke: Color = Arcana.Palette.glassStroke
    var strokeWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Arcana.Palette.glassFill)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: strokeWidth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
                    .blendMode(.overlay)
            )
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }
}

extension View {
    func glass(cornerRadius: CGFloat = 18,
               stroke: Color = Arcana.Palette.glassStroke,
               strokeWidth: CGFloat = 1) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, stroke: stroke, strokeWidth: strokeWidth))
    }
}

// MARK: - Shimmer sweep (`.shimbtn`)

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.22), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.6)
                }
                .allowsHitTesting(false)
                .mask(Rectangle())
            )
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

// MARK: - Starfield (`.sf`)

struct StarfieldView: View {
    var opacity: Double = 0.35
    /// Deterministic star positions so the field doesn't jump between renders.
    private let stars: [Star] = {
        var rng = SeededRNG(seed: 0xA11CE)
        return (0..<70).map { _ in
            Star(
                x: CGFloat(rng.next() % 1000) / 1000,
                y: CGFloat(rng.next() % 1000) / 1000,
                size: [1, 1, 1.5, 2][Int(rng.next() % 4)],
                twinkle: Double(rng.next() % 100) / 100
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: false)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for star in stars {
                    let pulse = 0.5 + 0.5 * sin(t * 1.4 + star.twinkle * 6.28)
                    let rect = CGRect(
                        x: star.x * size.width,
                        y: star.y * size.height,
                        width: star.size, height: star.size
                    )
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .color(Arcana.Palette.starGold.opacity(0.4 + 0.6 * pulse))
                    )
                }
            }
            .opacity(opacity)
        }
        .allowsHitTesting(false)
    }

    private struct Star { let x, y, size: CGFloat; let twinkle: Double }
}

/// Tiny deterministic PRNG (avoids `Math.random`-style nondeterminism between launches).
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
