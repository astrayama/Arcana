import SwiftUI

/// The three export canvases from wireframe 2f.
enum ExportTemplate: String, CaseIterable, Identifiable {
    case post   // social 1:1
    case story  // story 9:16
    case pdf    // A4 journal page

    var id: String { rawValue }

    var label: String {
        switch self {
        case .post: return "Post 1:1"
        case .story: return "Story 9:16"
        case .pdf: return "Journal PDF"
        }
    }

    /// Design size in points (rendered @3x for images).
    var size: CGSize {
        switch self {
        case .post: return CGSize(width: 360, height: 360)
        case .story: return CGSize(width: 360, height: 640)
        case .pdf: return CGSize(width: 595, height: 842)   // A4 @ 72dpi
        }
    }
}

/// Options mirrored from the web app (2f toggles).
struct ExportOptions {
    var includeNotes = true
    var cardImages = true
    var showDate = true
}

/// Pre-fetched art so ImageRenderer (which is synchronous) never sees a
/// placeholder. Values are nil when only the procedural face is available.
typealias CardImageCache = [String: UIImage]

@MainActor
func prefetchCardImages(for spread: Spread) async -> CardImageCache {
    var cache: CardImageCache = [:]
    for placed in spread.cards {
        guard let card = Deck.card(id: placed.cardID) else { continue }
        if let bundled = UIImage(named: card.imageName) {
            cache[card.id] = bundled
        } else if let url = CardArtView.remoteURL(for: card),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) {
            cache[card.id] = image
        }
    }
    return cache
}

// MARK: - Shared card cell used inside export canvases

private struct ExportCardCell: View {
    let placed: SpreadCard
    let cache: CardImageCache
    var width: CGFloat
    var labelColor: Color
    var nameColor: Color

    private var card: TarotCard? { Deck.card(id: placed.cardID) }

    var body: some View {
        VStack(spacing: 5) {
            Text(placed.position.uppercased())
                .font(AppFont.body(width * 0.105, weight: .bold))
                .kerning(1.1)
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Group {
                if let card, let image = cache[card.id] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let card {
                    ProceduralCardFace(card: card)
                }
            }
            .frame(width: width, height: width * 1.66)
            .clipShape(RoundedRectangle(cornerRadius: width * 0.07))
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.07)
                    .strokeBorder(Arcana.Palette.gold.opacity(0.45), lineWidth: 1)
            )
            .rotationEffect(placed.orientation == .reversed ? .degrees(180) : .zero)

            if let card {
                Text(placed.orientation == .reversed ? "\(card.name) (R)" : card.name)
                    .font(AppFont.body(width * 0.12, weight: .bold))
                    .foregroundStyle(nameColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.65)
                    .frame(width: width * 1.15)
            }
        }
    }
}

/// Text-only fallback rows when the "Card images" toggle is off.
private struct ExportCardList: View {
    let spread: Spread
    var color: Color
    var accent: Color
    var fontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.55) {
            ForEach(spread.cards) { placed in
                if let card = Deck.card(id: placed.cardID) {
                    HStack(spacing: 8) {
                        Text(placed.position)
                            .font(AppFont.body(fontSize, weight: .bold))
                            .foregroundStyle(accent)
                        Text("\(card.name) \(placed.orientation.arrow)")
                            .font(AppFont.body(fontSize))
                            .foregroundStyle(color)
                    }
                }
            }
        }
    }
}

// MARK: - Post 1:1 (social square)

struct PostExportView: View {
    let spread: Spread
    let options: ExportOptions
    let cache: CardImageCache

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x12101C), Color(hex: 0x171327)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: 0x583A8A).opacity(0.4), .clear],
                           center: UnitPoint(x: 0.25, y: 0.15), startRadius: 0, endRadius: 260)
            StaticStars(count: 40)

            VStack(spacing: 14) {
                if options.showDate {
                    Text("✦ \(spread.date.formatted(.dateTime.month(.wide).day()).uppercased()) ✦")
                        .font(AppFont.display(11))
                        .kerning(2)
                        .foregroundStyle(Arcana.Palette.gold)
                }

                Text(spread.title)
                    .font(AppFont.display(26, weight: .medium))
                    .foregroundStyle(Arcana.Palette.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                if options.cardImages {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(spread.cards.prefix(5)) { placed in
                            ExportCardCell(placed: placed, cache: cache,
                                           width: spread.cards.count <= 3 ? 72 : 48,
                                           labelColor: Arcana.Palette.muted,
                                           nameColor: Arcana.Palette.text)
                        }
                    }
                    if spread.cards.count > 5 {
                        Text("+ \(spread.cards.count - 5) more in the full spread")
                            .font(AppFont.body(10))
                            .foregroundStyle(Arcana.Palette.faint)
                    }
                } else {
                    ExportCardList(spread: spread, color: Arcana.Palette.text,
                                   accent: Arcana.Palette.gold, fontSize: 13)
                }

                if options.includeNotes, !spread.note.isEmpty {
                    Text("“\(spread.note)”")
                        .font(AppFont.body(11.5))
                        .italic()
                        .foregroundStyle(Arcana.Palette.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 30)
                }

                Text("— Arcana —")
                    .font(AppFont.display(10))
                    .kerning(2)
                    .foregroundStyle(Arcana.Palette.faint)
            }
            .padding(24)
        }
        .frame(width: ExportTemplate.post.size.width, height: ExportTemplate.post.size.height)
    }
}

// MARK: - Story 9:16

struct StoryExportView: View {
    let spread: Spread
    let options: ExportOptions
    let cache: CardImageCache

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x12101C), Color(hex: 0x1A1530)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: 0x583A8A).opacity(0.38), .clear],
                           center: UnitPoint(x: 0.2, y: 0.1), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Color(hex: 0x1E4A66).opacity(0.3), .clear],
                           center: UnitPoint(x: 0.85, y: 0.9), startRadius: 0, endRadius: 380)
            StaticStars(count: 70)

            VStack(spacing: 22) {
                Spacer()

                if options.showDate {
                    Text("✦ \(spread.date.formatted(.dateTime.month(.wide).day()).uppercased()) ✦")
                        .font(AppFont.display(13))
                        .kerning(2.4)
                        .foregroundStyle(Arcana.Palette.gold)
                }

                Text(spread.title)
                    .font(AppFont.display(34, weight: .medium))
                    .foregroundStyle(Arcana.Palette.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 28)

                if options.cardImages {
                    // Eager rows (not LazyVGrid) — this view also renders offscreen
                    // through ImageRenderer, where lazy containers can come up empty.
                    let compact = spread.cards.count > 3
                    let rows = spread.cards.prefix(9).chunked(into: 3)
                    VStack(spacing: 18) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(row) { placed in
                                    ExportCardCell(placed: placed, cache: cache,
                                                   width: compact ? 62 : 84,
                                                   labelColor: Arcana.Palette.muted,
                                                   nameColor: Arcana.Palette.text)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                } else {
                    ExportCardList(spread: spread, color: Arcana.Palette.text,
                                   accent: Arcana.Palette.gold, fontSize: 15)
                }

                if options.includeNotes, !spread.note.isEmpty {
                    Text("“\(spread.note)”")
                        .font(AppFont.body(14))
                        .italic()
                        .foregroundStyle(Arcana.Palette.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .lineLimit(6)
                        .padding(.horizontal, 36)
                }

                Spacer()

                Text("— Arcana —")
                    .font(AppFont.display(12))
                    .kerning(2.4)
                    .foregroundStyle(Arcana.Palette.faint)
                    .padding(.bottom, 30)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(Arcana.Palette.gold.opacity(0.35), lineWidth: 2)
                .padding(10)
        )
        .frame(width: ExportTemplate.story.size.width, height: ExportTemplate.story.size.height)
    }
}

// MARK: - Journal page PDF (A4, parchment — for the archive)

struct JournalPageExportView: View {
    let spread: Spread
    let options: ExportOptions
    let cache: CardImageCache

    private let ink = Color(hex: 0x2E2438)
    private let sepia = Color(hex: 0x8A5A3B)
    private let rule = Color(hex: 0xD8CCB4)

    var body: some View {
        ZStack {
            Color(hex: 0xF5EFE2)

            VStack(alignment: .leading, spacing: 20) {
                // Title block
                VStack(alignment: .leading, spacing: 8) {
                    Text(spread.title)
                        .font(AppFont.display(30, weight: .medium))
                        .foregroundStyle(ink)
                    if options.showDate {
                        Text("\(spread.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())) · \(spread.templateName)")
                            .font(AppFont.body(12))
                            .foregroundStyle(sepia)
                    }
                    Rectangle().fill(rule).frame(width: 260, height: 2)
                }

                if options.cardImages {
                    HStack(alignment: .top, spacing: 26) {
                        ForEach(spread.cards.prefix(5)) { placed in
                            ExportCardCell(placed: placed, cache: cache,
                                           width: spread.cards.count <= 3 ? 108 : 78,
                                           labelColor: sepia, nameColor: ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if spread.cards.count > 5 {
                        // Remaining positions listed below the pictured row.
                        ExportCardList(spread: Spread(
                            title: spread.title, templateID: spread.templateID,
                            templateName: spread.templateName,
                            cards: Array(spread.cards.dropFirst(5)),
                            note: spread.note, date: spread.date
                        ), color: ink, accent: sepia, fontSize: 12)
                    }
                } else {
                    ExportCardList(spread: spread, color: ink, accent: sepia, fontSize: 13)
                }

                if options.includeNotes, !spread.note.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("NOTES")
                            .font(AppFont.body(10, weight: .bold))
                            .kerning(1.6)
                            .foregroundStyle(sepia)
                        Text(spread.note)
                            .font(AppFont.body(13))
                            .foregroundStyle(ink)
                            .lineSpacing(9)
                    }
                    .padding(.top, 6)
                }

                Spacer()

                HStack {
                    Rectangle().fill(rule).frame(height: 1)
                    Text("Arcana · journal page")
                        .font(AppFont.display(10))
                        .foregroundStyle(sepia)
                        .fixedSize()
                    Rectangle().fill(rule).frame(height: 1)
                }
            }
            .padding(52)
        }
        .frame(width: ExportTemplate.pdf.size.width, height: ExportTemplate.pdf.size.height)
    }
}

extension Collection {
    /// Split into rows of at most `size` elements.
    func chunked(into size: Int) -> [[Element]] {
        var result: [[Element]] = []
        var row: [Element] = []
        for element in self {
            row.append(element)
            if row.count == size { result.append(row); row = [] }
        }
        if !row.isEmpty { result.append(row) }
        return result
    }
}

// MARK: - Non-animated starfield for renders

/// Deterministic, static stars (TimelineView-based fields don't belong in a
/// one-shot ImageRenderer snapshot).
struct StaticStars: View {
    var count: Int

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 0x57A125)
            for _ in 0..<count {
                let x = CGFloat(rng.next() % 1000) / 1000 * size.width
                let y = CGFloat(rng.next() % 1000) / 1000 * size.height
                let r = [1.0, 1.0, 1.5, 2.0][Int(rng.next() % 4)]
                let alpha = 0.3 + Double(rng.next() % 60) / 100
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(Arcana.Palette.starGold.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }
}
