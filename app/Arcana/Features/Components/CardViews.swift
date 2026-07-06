import SwiftUI

// MARK: - Card art

/// Renders a tarot card's art at any size.
///
/// Resolution order:
/// 1. Bundled asset named `card-<id>` (run `app/scripts/fetch-card-art.sh` to bundle all 78);
/// 2. Public-domain RWS scan from Wikimedia Commons (cached by URLCache);
/// 3. Procedural "cosmic" card face with the card's numeral and name.
struct CardArtView: View {
    let card: TarotCard
    var orientation: Orientation = .upright

    var body: some View {
        Group {
            if UIImage(named: card.imageName) != nil {
                Image(card.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AsyncImage(url: Self.remoteURL(for: card)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        ProceduralCardFace(card: card)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Arcana.Palette.gold.opacity(0.4), lineWidth: 1)
        )
        .rotationEffect(orientation == .reversed ? .degrees(180) : .zero)
    }

    /// Wikimedia Commons public-domain RWS scans (same source as the wireframes).
    static func remoteURL(for card: TarotCard) -> URL? {
        let file: String
        switch card.arcana {
        case .major:
            let names = [
                "RWS_Tarot_00_Fool", "RWS_Tarot_01_Magician", "RWS_Tarot_02_High_Priestess",
                "RWS_Tarot_03_Empress", "RWS_Tarot_04_Emperor", "RWS_Tarot_05_Hierophant",
                "RWS_Tarot_06_Lovers", "RWS_Tarot_07_Chariot", "RWS_Tarot_08_Strength",
                "RWS_Tarot_09_Hermit", "RWS_Tarot_10_Wheel_of_Fortune", "RWS_Tarot_11_Justice",
                "RWS_Tarot_12_Hanged_Man", "RWS_Tarot_13_Death", "RWS_Tarot_14_Temperance",
                "RWS_Tarot_15_Devil", "RWS_Tarot_16_Tower", "RWS_Tarot_17_Star",
                "RWS_Tarot_18_Moon", "RWS_Tarot_19_Sun", "RWS_Tarot_20_Judgement",
                "RWS_Tarot_21_World",
            ]
            guard card.number < names.count else { return nil }
            file = names[card.number] + ".jpg"
        case .minor:
            guard let suit = card.suit else { return nil }
            let prefix: String
            switch suit {
            case .wands: prefix = "Wands"
            case .cups: prefix = "Cups"
            case .swords: prefix = "Swords"
            case .pentacles: prefix = "Pents"
            }
            file = String(format: "%@%02d.jpg", prefix, card.number)
        }
        return URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(file)")
    }
}

/// Offline fallback card face in the app's cosmic style.
struct ProceduralCardFace: View {
    let card: TarotCard

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x241E37), Color(hex: 0x171422)],
                    startPoint: .top, endPoint: .bottom
                )
                StarfieldView(opacity: 0.3)
                VStack(spacing: geo.size.height * 0.06) {
                    Text(card.numeral)
                        .font(AppFont.display(geo.size.height * 0.11, weight: .semibold))
                        .foregroundStyle(Arcana.Palette.gold)
                    Text(glyph)
                        .font(.system(size: geo.size.height * 0.24))
                        .foregroundStyle(Arcana.Palette.gold.opacity(0.75))
                    Text(card.name)
                        .font(AppFont.display(geo.size.height * 0.075))
                        .foregroundStyle(Arcana.Palette.text)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .aspectRatio(0.6, contentMode: .fill)
    }

    private var glyph: String {
        switch card.suit {
        case .wands: return "☩"
        case .cups: return "♡"
        case .swords: return "⚔"
        case .pentacles: return "✪"
        case nil: return "☾"
        }
    }
}

/// The card back (`.cback`): deep gradient, gold border, moon glyph.
struct CardBackView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x241E37), Color(hex: 0x171422)],
                    startPoint: UnitPoint(x: 0.2, y: 0), endPoint: UnitPoint(x: 0.8, y: 1)
                )
                Text("☾")
                    .font(.system(size: geo.size.height * 0.18))
                    .foregroundStyle(Arcana.Palette.gold.opacity(0.75))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Arcana.Palette.gold.opacity(0.42), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.45), radius: 9, y: 6)
    }
}

// MARK: - Ambient card animations (`hfloat` / `hglow`)

/// Slow vertical drift — "card art floats + breathes gold (6s loop)".
struct FloatingModifier: ViewModifier {
    @State private var up = false
    var amplitude: CGFloat = 6
    var period: Double = 6

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -amplitude : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
    }
}

/// Breathing gold glow.
struct GoldGlowModifier: ViewModifier {
    @State private var bright = false
    var period: Double = 6

    func body(content: Content) -> some View {
        content
            .shadow(color: Arcana.Palette.gold.opacity(bright ? 0.42 : 0.22),
                    radius: bright ? 30 : 16)
            .onAppear {
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}

/// Twinkling sparkle (`.spark`).
struct SparkleText: View {
    var size: CGFloat = 14
    var color: Color = Arcana.Palette.gold
    var delay: Double = 0
    @State private var lit = false

    var body: some View {
        Text("✦")
            .font(.system(size: size))
            .foregroundStyle(color)
            .opacity(lit ? 1 : 0.3)
            .scaleEffect(lit ? 1.2 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(delay)) {
                    lit = true
                }
            }
    }
}

extension View {
    func floating(amplitude: CGFloat = 6, period: Double = 6) -> some View {
        modifier(FloatingModifier(amplitude: amplitude, period: period))
    }
    func goldGlow(period: Double = 6) -> some View {
        modifier(GoldGlowModifier(period: period))
    }
}
