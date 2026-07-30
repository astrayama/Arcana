import SwiftUI
import CoreMotion
import QuartzCore

/// In-app draw — wireframe 2c. Hold a question in mind, then tilt the phone to
/// riffle through all 78 face-down cards; the centered card is the active one.
/// Hold-to-draw fills the ring and the active card flips over with a crisp tick.
struct DrawView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private enum Phase { case idle, revealing, revealed }

    @State private var phase: Phase = .idle
    @State private var drawn: (card: TarotCard, orientation: Orientation)?
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var flipAngle: Double = 0
    @State private var deckMotion = DeckMotionModel()
    @State private var shuffledDeck: [TarotCard] = Deck.all.shuffled()

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
        .onAppear { deckMotion.start() }
        .onDisappear { deckMotion.stop(); holdTimer?.invalidate() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                deckMotion.start()
                deckMotion.recalibrate()
            } else {
                deckMotion.stop()
            }
        }
    }

    // MARK: Idle — question + 78-card carousel + hold ring

    private var idleContent: some View {
        VStack(spacing: 22) {
            Text("Hold a question\nin mind")
                .displayFont(25)
                .foregroundStyle(Arcana.Palette.text)
                .multilineTextAlignment(.center)

            DeckCarouselView(model: deckMotion, deck: shuffledDeck)

            Text(deckMotion.motionAvailable
                 ? "tilt to shuffle · hold to draw"
                 : "swipe the deck to shuffle · hold to draw")
                .bodyFont(13)
                .foregroundStyle(Arcana.Palette.muted)

            holdRing
        }
        .padding(.horizontal, 24)
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
        .accessibilityLabel("Hold to draw the centered card")
    }

    private func startHold() {
        guard holdTimer == nil, phase == .idle else { return }
        // Freeze the riffle so the card being committed to can't drift mid-hold.
        deckMotion.freeze()
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
        deckMotion.unfreeze()
        withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
    }

    private func drawCard() {
        let card = shuffledDeck[deckMotion.activeIndex]
        let orientation: Orientation = Bool.random() ? .reversed : .upright
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
                
                Text(drawn.orientation == .upright ? drawn.card.uprightKeywords : drawn.card.reversedKeywords)
                    .bodyFont(13)
                    .foregroundStyle(Arcana.Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                HStack(spacing: 12) {
                    GoldButton(title: "Journal it") {
                        Task {
                            if let existing = store.todayPull {
                                var updated = existing
                                updated.cardID = drawn.card.id
                                updated.orientation = drawn.orientation
                                await store.save(updated)
                            } else {
                                let pull = CardPull(cardID: drawn.card.id, orientation: drawn.orientation, note: "", date: Date())
                                await store.save(pull)
                            }
                            dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    GlassButton(title: "Draw again ↺") {
                        withAnimation(.snappy) {
                            phase = .idle
                            holdProgress = 0
                            self.drawn = nil
                        }
                        // Fresh shuffle ritual: new order, recentered, regrip as neutral.
                        shuffledDeck = Deck.all.shuffled()
                        deckMotion.reset()
                        deckMotion.unfreeze()
                    }
                    .frame(width: 130)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - 78-card carousel

/// The full deck fanned as a riffle arc, face down. This is the only view that
/// reads `model.position`, so the 60 Hz motion updates re-render just this
/// subtree — never the whole `DrawView` body.
private struct DeckCarouselView: View {
    let model: DeckMotionModel
    let deck: [TarotCard]

    @State private var isDragging = false

    var body: some View {
        let position = model.position
        // Only the cards whose opacity is > 0 are in the tree (≤11 of 78);
        // the fade-out below reaches 0 before the window edge, so cards
        // enter and leave invisibly.
        let lo = max(0, Int(ceil(position - 5)))
        let hi = min(deck.count - 1, Int(floor(position + 5)))

        VStack(spacing: 14) {
            ZStack {
                // One shared pool of shadow; the card backs render shadow-free.
                Ellipse()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 250, height: 54)
                    .blur(radius: 18)
                    .offset(y: 100)

                ForEach(lo...hi, id: \.self) { index in
                    card(at: index, position: position)
                }
            }
            .frame(width: 340, height: 224)
            .contentShape(Rectangle())
            .gesture(scrubGesture)

            Text("\(model.activeIndex + 1) of \(deck.count)")
                .bodyFont(12, weight: .semibold)
                .foregroundStyle(Arcana.Palette.faint)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card deck")
        .accessibilityValue("Card \(model.activeIndex + 1) of \(deck.count)")
        .accessibilityHint("Tilt the phone or swipe to shuffle. Hold the button below to draw the centered card.")
        .accessibilityAdjustableAction { direction in
            model.nudge(direction == .increment ? 1 : -1)
        }
    }

    /// Coverflow-style transforms as functions of the card's signed distance
    /// from the continuous deck position. No implicit animations — the 60 Hz
    /// integrator in `DeckMotionModel` is the animation.
    private func card(at index: Int, position: CGFloat) -> some View {
        let d = CGFloat(index) - position
        let absD = abs(d)
        let center = max(0, 1 - absD)   // 1 at the active card, 0 by its neighbors
        return CardBackView(showsShadow: false)
            .frame(width: 94, height: 156)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(min(0.45, absD * 0.11)))
            )
            .shadow(color: Arcana.Palette.gold.opacity(center * 0.35), radius: 16)
            .scaleEffect(1 + center * 0.08)
            .rotationEffect(.degrees(d * 8))
            .offset(x: d * 42, y: d * d * 2.5 - center * 10)
            .opacity(absD <= 3.5 ? 1 : max(0, 1 - (absD - 3.5) / 1.5))
            .zIndex(Double(-absD))
    }

    /// Drag scrub — the only input on the Simulator (no device motion) and a
    /// handy override on device. Separate view from the hold ring, no conflict.
    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    model.beginScrub()
                }
                model.scrub(translation: value.translation.width)
            }
            .onEnded { value in
                isDragging = false
                model.endScrub(translation: value.translation.width,
                               predicted: value.predictedEndTranslation.width)
            }
    }
}

// MARK: - Deck motion

/// Velocity-integrated device roll drives a continuous position through the
/// deck: tilting past a small dead zone riffles the cards, leveling the phone
/// settles onto the nearest one. The roll baseline is the grip captured on
/// start, so a natural reading angle keeps the deck still. Falls back to drag
/// scrubbing where device motion is unavailable (e.g. the Simulator).
@Observable
final class DeckMotionModel {
    // MARK: Tuning
    private let deadZone: CGFloat = 0.07      // rad (~4°) of roll ignored around neutral
    private let gain: CGFloat = 30            // cards/sec per rad beyond the dead zone
    private let maxSpeed: CGFloat = 14        // cards/sec cap (full deck in ~6s)
    private let smoothing: CGFloat = 0.15     // roll low-pass factor (~0.1s @ 60 Hz)
    private let pointsPerCard: CGFloat = 36   // drag-scrub mapping

    // MARK: Read by views
    private(set) var position: CGFloat        // continuous, 0...(count-1)
    private(set) var activeIndex: Int         // written only when it changes
    let motionAvailable: Bool

    let centerIndex: Int
    private let lastIndex: CGFloat
    private let manager: CMMotionManager

    @ObservationIgnored private var frameTimer: Timer?
    @ObservationIgnored private var referenceAttitude: CMAttitude?
    @ObservationIgnored private var smoothedRoll: CGFloat = 0
    @ObservationIgnored private var velocity: CGFloat = 0
    @ObservationIgnored private var lastFrameTime: TimeInterval?
    @ObservationIgnored private var isFrozen = false
    @ObservationIgnored private var isScrubbing = false
    @ObservationIgnored private var scrubAnchor: CGFloat = 0
    @ObservationIgnored private var wasAtEnd = false
    @ObservationIgnored private var lastTickTime: TimeInterval = 0

    init(cardCount: Int = Deck.all.count) {
        let center = (cardCount - 1) / 2
        let motion = CMMotionManager()
        centerIndex = center
        lastIndex = CGFloat(cardCount - 1)
        position = CGFloat(center)
        activeIndex = center
        manager = motion
        motionAvailable = motion.isDeviceMotionAvailable
    }

    // MARK: Lifecycle

    func start() {
        if motionAvailable, !manager.isDeviceMotionActive {
            manager.deviceMotionUpdateInterval = 1 / 60
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self, let attitude = motion?.attitude else { return }
                guard let reference = self.referenceAttitude else {
                    // First sample: the current grip becomes neutral.
                    self.referenceAttitude = attitude.copy() as? CMAttitude
                    return
                }
                let relative = attitude.copy() as! CMAttitude
                relative.multiply(byInverseOf: reference)
                self.smoothedRoll += self.smoothing * (CGFloat(relative.roll) - self.smoothedRoll)
            }
        }
        if frameTimer == nil {
            lastFrameTime = nil
            let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
                self?.step()
            }
            // .common so the riffle keeps integrating while a gesture is tracking.
            RunLoop.main.add(timer, forMode: .common)
            frameTimer = timer
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        frameTimer?.invalidate(); frameTimer = nil
        velocity = 0
    }

    /// Re-capture the neutral grip on the next motion sample (e.g. after
    /// returning from the background, where the hold likely changed).
    func recalibrate() {
        referenceAttitude = nil
        smoothedRoll = 0
    }

    // MARK: Hold / draw

    /// A hold began: stop the scroll and snap so the active card is
    /// unambiguous while the ring fills.
    func freeze() {
        isFrozen = true
        velocity = 0
        commit(position.rounded(), now: CACurrentMediaTime())
    }

    func unfreeze() {
        isFrozen = false
    }

    /// Draw again: recenter on the (re)shuffled deck and re-zero the grip.
    func reset() {
        velocity = 0
        wasAtEnd = false
        if CGFloat(centerIndex) != position { position = CGFloat(centerIndex) }
        if centerIndex != activeIndex { activeIndex = centerIndex }
        recalibrate()
    }

    // MARK: Drag scrub

    func beginScrub() {
        isScrubbing = true
        scrubAnchor = position
        velocity = 0
    }

    /// Dragging left advances through the deck (cards are laid out left→right).
    func scrub(translation: CGFloat) {
        guard isScrubbing else { return }
        commit(scrubAnchor - translation / pointsPerCard, now: CACurrentMediaTime())
    }

    func endScrub(translation: CGFloat, predicted: CGFloat) {
        isScrubbing = false
        // Seed a fling from the gesture's projected remainder; the frame
        // timer's settle logic then lands it on a card.
        let fling = -(predicted - translation) / pointsPerCard / 0.4
        velocity = min(maxSpeed, max(-maxSpeed, fling))
    }

    /// VoiceOver adjustable action: step one card without tilting.
    func nudge(_ delta: Int) {
        velocity = 0
        commit(position.rounded() + CGFloat(delta), now: CACurrentMediaTime())
    }

    // MARK: Integrator

    private func step() {
        let now = CACurrentMediaTime()
        // Clamp dt so a stall or backgrounding can't teleport the deck.
        let dt = min(now - (lastFrameTime ?? now), 0.05)
        lastFrameTime = now
        guard !isFrozen, !isScrubbing else { return }

        // Tilt beyond the dead zone maps to a capped scroll velocity.
        let excess = max(0, abs(smoothedRoll) - deadZone)
        let target = min(maxSpeed, gain * excess) * (smoothedRoll < 0 ? -1 : 1)
        velocity += (target - velocity) * min(1, 10 * dt)

        var p = position + velocity * dt
        let hitEnd = p <= 0 || p >= lastIndex
        if hitEnd {
            p = min(lastIndex, max(0, p))
            if !wasAtEnd, abs(velocity) > 2 { Haptics.soft() }   // end-of-deck thud
            velocity = 0
        }
        wasAtEnd = hitEnd

        // Level and slow → settle onto the nearest card, never between two.
        if excess == 0, abs(velocity) < 0.8 {
            let snap = p.rounded()
            p += (snap - p) * min(1, 8 * dt)
            if abs(p - snap) < 0.01 { p = snap; velocity = 0 }
        }

        commit(p, now: now)
    }

    /// Single write path: clamps, publishes only real changes, and drives the
    /// haptic ratchet as the active card passes the center.
    private func commit(_ newPosition: CGFloat, now: TimeInterval) {
        let clamped = min(lastIndex, max(0, newPosition))
        if clamped != position { position = clamped }
        let index = Int(clamped.rounded())
        if index != activeIndex {
            activeIndex = index
            if now - lastTickTime > 0.04 {   // throttle when riffling fast
                Haptics.tick()
                lastTickTime = now
            }
        }
    }
}
