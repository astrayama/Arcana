import WidgetKit
import SwiftUI

// MARK: - Shared snapshot (written by the app into the app group)

struct Snapshot: Codable {
    var date: Date
    var cardID: String?
    var cardName: String?
    var orientation: String?
    var streak: Int
    var imageURLString: String?

    var isLoggedToday: Bool {
        cardID != nil && Calendar.current.isDateInToday(date)
    }

    static func read() -> Snapshot? {
        guard let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.arcana.shared"),
              let data = try? Data(contentsOf: container.appendingPathComponent("widget-snapshot.json"))
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Snapshot.self, from: data)
    }
}

// MARK: - Timeline

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
    let cardImage: UIImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now,
              snapshot: Snapshot(date: .now, cardID: "major-18", cardName: "The Moon",
                                 orientation: "upright", streak: 12, imageURLString: nil),
              cardImage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let entry = await makeEntry()
            // Refresh just after midnight so "logged today" resets.
            let midnight = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
            ).addingTimeInterval(60)
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }

    private func makeEntry() async -> Entry {
        let snapshot = Snapshot.read()
        var image: UIImage?
        if let snapshot, snapshot.isLoggedToday {
            if let id = snapshot.cardID, let bundled = UIImage(named: "card-\(id)") {
                image = bundled
            } else if let urlString = snapshot.imageURLString, let url = URL(string: urlString),
                      let (data, _) = try? await URLSession.shared.data(from: url) {
                image = UIImage(data: data)
            }
        }
        return Entry(date: .now, snapshot: snapshot, cardImage: image)
    }
}

// MARK: - Palette (mirrors the app's cosmic-glass theme)

private enum Pal {
    static let text = Color(red: 0.949, green: 0.933, blue: 0.969)
    static let muted = Color(red: 0.651, green: 0.596, blue: 0.702)
    static let gold = Color(red: 0.965, green: 0.808, blue: 0.333)
    static let purple = Color(red: 0.702, green: 0.522, blue: 0.878)
    static let panelTop = Color(red: 0.071, green: 0.063, blue: 0.110)
    static let panelBottom = Color(red: 0.090, green: 0.075, blue: 0.153)
}

private struct WidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Pal.panelTop, Pal.panelBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.345, green: 0.227, blue: 0.541).opacity(0.4), .clear],
                           center: UnitPoint(x: 0.25, y: 0.15), startRadius: 0, endRadius: 160)
        }
    }
}

private struct MiniCardBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.141, green: 0.118, blue: 0.216),
                                          Color(red: 0.090, green: 0.078, blue: 0.133)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Pal.gold.opacity(0.42), lineWidth: 1.5)
            )
            .overlay(Text("☾").font(.system(size: 18)).foregroundStyle(Pal.gold.opacity(0.75)))
    }
}

// MARK: - Home-screen widget (small + medium)

struct TodayCardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ArcanaTodayCard", provider: Provider()) { entry in
            TodayCardWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Today's card")
        .description("Your daily pull and streak — tap to log.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayCardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        if family == .systemSmall {
            small
        } else {
            medium
        }
    }

    // small — "tap to log" / logged state
    private var small: some View {
        VStack(spacing: 8) {
            if let snapshot = entry.snapshot, snapshot.isLoggedToday {
                cardThumb(width: 46, height: 76)
                Text(snapshot.cardName ?? "Logged")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Pal.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("✦ \(snapshot.streak)-day streak")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Pal.gold)
            } else {
                MiniCardBack().frame(width: 46, height: 76)
                Text("Tap to log")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Pal.text)
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Pal.muted)
            }
        }
        .widgetURL(URL(string: entry.snapshot?.isLoggedToday == true
                       ? "arcana://today" : "arcana://log"))
    }

    // medium — card + streak + journal link
    private var medium: some View {
        HStack(spacing: 16) {
            if entry.snapshot?.isLoggedToday == true {
                cardThumb(width: 62, height: 104)
            } else {
                MiniCardBack().frame(width: 62, height: 104)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("TODAY'S CARD")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .kerning(1.4)
                    .foregroundStyle(Pal.gold)
                if let snapshot = entry.snapshot, snapshot.isLoggedToday {
                    Text("\(snapshot.cardName ?? "") \(snapshot.orientation == "reversed" ? "↓" : "↑")")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundStyle(Pal.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("✦ \(snapshot.streak)-day streak")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Pal.gold)
                    Text("open journal ›")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Pal.purple)
                        .padding(.top, 2)
                } else {
                    Text("Not logged yet")
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundStyle(Pal.text)
                    Text("Ten seconds — pull your card")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Pal.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: entry.snapshot?.isLoggedToday == true
                       ? "arcana://journal" : "arcana://log"))
    }

    @ViewBuilder
    private func cardThumb(width: CGFloat, height: CGFloat) -> some View {
        if let image = entry.cardImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Pal.gold.opacity(0.4), lineWidth: 1)
                )
                .rotationEffect(entry.snapshot?.orientation == "reversed" ? .degrees(180) : .zero)
        } else {
            MiniCardBack().frame(width: width, height: height)
        }
    }
}

// MARK: - Lock-screen widget (logged? ✓/○)

struct LockLoggedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ArcanaLockLogged", provider: Provider()) { entry in
            LockLoggedView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Logged today?")
        .description("A quiet moon — checked once today's card is in the ledger.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LockLoggedView: View {
    let entry: Entry

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.14))
            Text("☾").font(.system(size: 22))
            if entry.snapshot?.isLoggedToday == true {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .offset(x: 14, y: 14)
            }
        }
        .widgetURL(URL(string: "arcana://log"))
    }
}

// MARK: - Bundle

@main
struct ArcanaWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayCardWidget()
        LockLoggedWidget()
    }
}
