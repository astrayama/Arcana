import Foundation

/// One of the 78 cards of the Rider–Waite–Smith deck.
struct TarotCard: Identifiable, Codable, Hashable {
    enum Arcana: String, Codable, CaseIterable {
        case major, minor
    }

    enum Suit: String, Codable, CaseIterable {
        case wands, cups, swords, pentacles

        var displayName: String { rawValue.capitalized }
        var symbol: String {
            switch self {
            case .wands: return "🜂"
            case .cups: return "🜄"
            case .swords: return "🜁"
            case .pentacles: return "🜃"
            }
        }
    }

    /// Stable slug, e.g. `major-18` or `cups-10`. Used as the database key.
    let id: String
    let name: String
    let arcana: Arcana
    /// 0–21 for major arcana; 1–14 for minor (11 page, 12 knight, 13 queen, 14 king).
    let number: Int
    let suit: Suit?
    /// Upright keywords, e.g. "intuition, dreams, the subconscious".
    let uprightKeywords: String
    /// Reversed keywords.
    let reversedKeywords: String
    /// Roman numeral for majors ("XVIII"), rank name for minors ("Ten").
    var numeral: String {
        switch arcana {
        case .major: return Self.roman(number)
        case .minor: return Self.rankName(number)
        }
    }

    /// Subtitle shown under the card name, e.g. "XVIII · Major Arcana" / "Ten of Cups".
    var subtitle: String {
        switch arcana {
        case .major: return "\(Self.roman(number)) · Major Arcana"
        case .minor: return "\(numeral) of \(suit?.displayName ?? "")"
        }
    }

    /// Asset name for the bundled RWS card image, e.g. `card-major-18`.
    var imageName: String { "card-\(id)" }

    private static func roman(_ n: Int) -> String {
        guard n > 0 else { return "0" }
        let pairs: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
                                      (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
                                      (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n, out = ""
        for (v, s) in pairs { while n >= v { out += s; n -= v } }
        return out
    }

    private static func rankName(_ n: Int) -> String {
        switch n {
        case 1: return "Ace"
        case 2: return "Two"
        case 3: return "Three"
        case 4: return "Four"
        case 5: return "Five"
        case 6: return "Six"
        case 7: return "Seven"
        case 8: return "Eight"
        case 9: return "Nine"
        case 10: return "Ten"
        case 11: return "Page"
        case 12: return "Knight"
        case 13: return "Queen"
        case 14: return "King"
        default: return "\(n)"
        }
    }
}

/// Orientation of a pulled card.
enum Orientation: String, Codable, CaseIterable, Hashable {
    case upright, reversed

    var arrow: String { self == .upright ? "↑" : "↓" }
    var label: String { self == .upright ? "Upright" : "Reversed" }
}
