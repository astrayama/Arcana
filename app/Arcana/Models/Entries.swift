import Foundation

/// A single logged card — the daily pull or any one-off card entry.
struct CardPull: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var cardID: String
    var orientation: Orientation
    var note: String
    var date: Date
    /// Cached AI insight text, if one has been generated.
    var insight: String?
    var createdAt: Date = Date()
}

/// A named layout of positions (Past/Present/Future, Celtic Cross, custom…).
struct SpreadTemplate: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var positions: [String]

    static let threeCard = SpreadTemplate(
        id: "three-card", name: "Past · Present · Future",
        positions: ["Past", "Present", "Future"]
    )
    static let situationActionOutcome = SpreadTemplate(
        id: "sao", name: "Situation · Action · Outcome",
        positions: ["Situation", "Action", "Outcome"]
    )
    static let mindBodySpirit = SpreadTemplate(
        id: "mbs", name: "Mind · Body · Spirit",
        positions: ["Mind", "Body", "Spirit"]
    )
    static let celticCross = SpreadTemplate(
        id: "celtic-cross", name: "Celtic Cross",
        positions: ["Present", "Challenge", "Foundation", "Past", "Crown",
                    "Future", "Self", "Environment", "Hopes & Fears", "Outcome"]
    )
    static let single = SpreadTemplate(
        id: "single", name: "Single card",
        positions: ["The card"]
    )

    static let builtIn: [SpreadTemplate] = [
        .threeCard, .situationActionOutcome, .mindBodySpirit, .celticCross, .single,
    ]
}

/// One card placed into a spread position.
struct SpreadCard: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var position: String
    var cardID: String
    var orientation: Orientation
}

/// A completed reading: a titled spread with its cards and notes.
struct Spread: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var templateID: String
    var templateName: String
    var cards: [SpreadCard]
    var note: String
    var date: Date
    var insight: String?
    var createdAt: Date = Date()
}

/// Anything that appears as a row in the journal ledger.
enum JournalEntry: Identifiable, Hashable {
    case pull(CardPull)
    case spread(Spread)

    var id: UUID {
        switch self {
        case .pull(let p): return p.id
        case .spread(let s): return s.id
        }
    }

    var date: Date {
        switch self {
        case .pull(let p): return p.date
        case .spread(let s): return s.date
        }
    }
}

/// Journal statistics shown in the ledger header.
struct JournalStats {
    var streakDays: Int
    var cardCount: Int
    var spreadCount: Int
}
