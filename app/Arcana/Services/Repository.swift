import Foundation

/// Storage abstraction: the app runs against `LocalRepository` (seeded demo /
/// offline cache) until Supabase credentials are supplied, then `SupabaseRepository`.
protocol ArcanaRepository {
    func fetchPulls() async throws -> [CardPull]
    func fetchSpreads() async throws -> [Spread]
    func save(_ pull: CardPull) async throws
    func save(_ spread: Spread) async throws
    func deletePull(id: UUID) async throws
    func deleteSpread(id: UUID) async throws
}

// MARK: - Local repository (app-group JSON store)

/// Persists to a JSON file in the shared app-group container so the widget
/// extension can read the latest state, and data survives relaunches.
final class LocalRepository: ArcanaRepository {

    private struct Store: Codable {
        var pulls: [CardPull] = []
        var spreads: [Spread] = []
    }

    private let fileURL: URL
    private var store: Store

    init(seedDemoData: Bool) {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = container.appendingPathComponent("arcana-store.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder.arcana.decode(Store.self, from: data) {
            store = decoded
        } else {
            store = seedDemoData ? Self.demoStore() : Store()
            persist()
        }
    }

    func fetchPulls() async throws -> [CardPull] {
        store.pulls.sorted { $0.date > $1.date }
    }

    func fetchSpreads() async throws -> [Spread] {
        store.spreads.sorted { $0.date > $1.date }
    }

    func save(_ pull: CardPull) async throws {
        store.pulls.removeAll { $0.id == pull.id }
        store.pulls.append(pull)
        persist()
    }

    func save(_ spread: Spread) async throws {
        store.spreads.removeAll { $0.id == spread.id }
        store.spreads.append(spread)
        persist()
    }

    func deletePull(id: UUID) async throws {
        store.pulls.removeAll { $0.id == id }
        persist()
    }

    func deleteSpread(id: UUID) async throws {
        store.spreads.removeAll { $0.id == id }
        persist()
    }

    func eraseAll() {
        store = Store()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder.arcana.encode(store) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: demo seed — mirrors the wireframe journal exactly, relative to today

    private static func demoStore() -> Store {
        let cal = Calendar.current
        func day(_ offset: Int, note: String? = nil) -> Date {
            cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date()))!
                .addingTimeInterval(9 * 3600)
        }

        var pulls: [CardPull] = [
            CardPull(cardID: "major-18", orientation: .upright,
                     note: "Strange dreams again — trusting the undercurrent even when the path isn't lit.",
                     date: day(0)),
            CardPull(cardID: "cups-10", orientation: .reversed,
                     note: "Family dinner went sideways — the harmony is there, just out of tune tonight.",
                     date: day(1)),
            CardPull(cardID: "major-17", orientation: .upright,
                     note: "A good omen before the interview.",
                     date: day(2)),
            CardPull(cardID: "major-9", orientation: .upright,
                     note: "",
                     date: day(3)),
        ]
        // Extend the streak back to 12 days, like the wireframe stats header.
        let filler = ["wands-3", "major-2", "pentacles-9", "swords-6", "major-10",
                      "cups-2", "wands-11", "major-14"]
        for (i, id) in filler.enumerated() {
            pulls.append(CardPull(cardID: id, orientation: i % 3 == 2 ? .reversed : .upright,
                                  note: "", date: day(4 + i)))
        }

        let career = Spread(
            title: "Career check-in",
            templateID: SpreadTemplate.threeCard.id,
            templateName: SpreadTemplate.threeCard.name,
            cards: [
                SpreadCard(position: "Past", cardID: "major-17", orientation: .upright),
                SpreadCard(position: "Present", cardID: "major-19", orientation: .upright),
                SpreadCard(position: "Future", cardID: "cups-10", orientation: .reversed),
            ],
            note: "Momentum from past hope into present clarity — but the reversed Ten warns me not to trade home life for the promotion.",
            date: day(0)
        )
        let weekAhead = Spread(
            title: "Week ahead",
            templateID: SpreadTemplate.mindBodySpirit.id,
            templateName: SpreadTemplate.mindBodySpirit.name,
            cards: [
                SpreadCard(position: "Mind", cardID: "swords-1", orientation: .upright),
                SpreadCard(position: "Body", cardID: "pentacles-4", orientation: .reversed),
                SpreadCard(position: "Spirit", cardID: "major-17", orientation: .upright),
            ],
            note: "Clarity up top, loosen the grip, keep the faith.",
            date: day(6)
        )
        return Store(pulls: pulls, spreads: [career, weekAhead])
    }
}

// MARK: - Codable helpers

extension JSONEncoder {
    static let arcana: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let arcana: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
