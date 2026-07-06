import SwiftUI
import CoreMotion

/// In-app draw — wireframe 2c. Hold a question in mind, the fanned deck drifts
/// with device tilt, hold-to-draw fills the ring, then a 3D flip reveals the card
/// with a crisp haptic tick.
struct DrawView: View {
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case idle, revealing, revealed }

    @State private var phase: Phase = .idle
    @State private var drawn: (card: TarotCard, orientation: Orientation)?
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var flipAngle: Double = 0
    @StateObject private var tilt = TiltModel()

    var body: some View {
        ZStack {
            Arcana.CosmosBackground()
            StarfieldView(opacity: 0.55)

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(Arcana.Palette.faint)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                switch phase {
                case .idle: idleContent
                case .revealing, .revealed: revealContent
                }

                Spacer()
            }
        }
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop(); holdTimer?.invalidate() }
    }

    // MARK: Idle — question + fan + hold ring

    private var idleContent: some View {
        VStack(spacing: 26) {
            Text("Hold a question\nin mind")
                .displayFont(25)
                .foregroundStyle(Arcana.Palette.text)
                .multilineTextAlignment(.center)

            deckFan

            Text("the deck drifts as you tilt the phone")
                .bodyFont(13)
                .foregroundStyle(Arcana.Palette.muted)

            holdRing
        }
        .padding(.horizontal, 24)
    }

    /// Five fanned card backs (`2c`), parallaxed by device motion.
    private var deckFan: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                let angle = Double(i - 2) * 11.0
                let lift: CGFloat = abs(CGFloat(i - 2)) * 18
                CardBackView()
                    .frame(width: 94, height: 156)
                    .rotationEffect(.degrees(angle))
                    .offset(x: CGFloat(i - 2) * 58, y: lift)
                    // Deeper cards drift slightly more — cheap parallax.
                    .offset(x: tilt.x * (6 + CGFloat(i) * 2),
                            y: tilt.y * (4 + CGFloat(i) * 1.5))
                    .animation(.easeOut(duration: 0.25), value: tilt.x)
            }
        }
        .frame(width: 340, height: 220)
    }

    /// Hold-to-draw: the gold ring fills while pressed; release early to reset.
    private var holdRing: some View {
        ZStack {
            Circle()
                .stroke(Arcana.Palette.gold.opacity(0.25), lineWidth: 2)
            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(Arcana.Palette.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("HOLD")
                .bodyFont(13, weight: .heavy)
                .kerning(1.5)
                .foregroundStyle(Arcana.Palette.gold)
        }
        .frame(width: 82, height: 82)
        .shadow(color: Arcana.Palette.gold.opacity(0.2), radius: 13)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in cancelHold() }
        )
        .accessibilityLabel("Hold to draw a card")
    }

    private func startHold() {
        guard holdTimer == nil, phase == .idle else { return }
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { _ in
            holdProgress += (1 / 60) / 1.2   // ~1.2s to fill
            if holdProgress >= 1 {
                holdTimer?.invalidate(); holdTimer = nil
                drawCard()
            }
        }
    }

    private func cancelHold() {
        guard phase == .idle else { return }
        holdTimer?.invalidate(); holdTimer = nil
        withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
    }

    private func drawCard() {
        let card = Deck.all.randomElement()!
        let orientation: Orientation = Int.random(in: 0..<3) == 0 ? .reversed : .upright
        drawn = (card, orientation)
        phase = .revealing
        flipAngle = 0
        // 3D flip: back → 90° (swap face) → 0°, with a crisp tick at the reveal.
        withAnimation(.easeIn(duration: 0.28)) { flipAngle = 90 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            Haptics.tick()
            phase = .revealed
            flipAngle = -90
            withAnimation(.easeOut(duration: 0.32)) { flipAngle = 0 }
        }
    }

    // MARK: Reveal

    private var revealContent: some View {
        VStack(spacing: 14) {
            Text("YOUR CARD")
                .bodyFont(10.5, weight: .bold)
                .kerning(1.6)
                .foregroundStyle(Arcana.Palette.gold)

            Group {
                if phase == .revealed, let drawn {
                    CardArtView(card: drawn.card, orientation: drawn.orientation)
                        .goldGlow(period: 5)
                } else {
                    CardBackView()
                }
            }
            .frame(width: 200, height: 334)
            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)

            if phase == .revealed, let drawn {
                Text(drawn.card.name)
                    .displayFont(32)
                    .foregroundStyle(Arcana.Palette.text)

                Chip(label: "\(drawn.orientation.arrow) \(drawn.orientation.label)", isOn: true)

                HStack(spacing: 12) {
                    GoldButton(title: "Journal it") {
                        router.prefillCardID = drawn.card.id
                        router.prefillOrientation = drawn.orientation
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            router.showQuickLog = true
                        }
                    }
                    .frame(maxWidth: .infinity)

                    GlassButton(title: "Draw again ↺") {
                        withAnimation(.snappy) {
                            phase = .idle
                            holdProgress = 0
                            self.drawn = nil
                        }
                    }
                    .frame(width: 130)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Device tilt

/// Publishes a gentle normalized tilt offset from CoreMotion (falls back to zero
/// in the simulator or when motion is unavailable).
final class TiltModel: ObservableObject {
    @Published var x: CGFloat = 0
    @Published var y: CGFloat = 0
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }
            // Clamp to keep the drift subtle.
            self.x = CGFloat(max(-1, min(1, attitude.roll / 0.8)))
            self.y = CGFloat(max(-1, min(1, attitude.pitch / 0.8)))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
