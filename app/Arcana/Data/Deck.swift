import Foundation

/// The full 78-card Rider–Waite–Smith deck with upright / reversed keywords.
enum Deck {

    static func card(id: String) -> TarotCard? { byID[id] }

    static let byID: [String: TarotCard] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    static func search(_ query: String) -> [TarotCard] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.lowercased().contains(q) ||
            $0.uprightKeywords.lowercased().contains(q) ||
            ($0.suit?.rawValue.contains(q) ?? false)
        }
    }

    static let majors: [TarotCard] = [
        major(0, "The Fool", "new beginnings, spontaneity, a leap of faith", "recklessness, hesitation, holding back"),
        major(1, "The Magician", "manifestation, willpower, resourcefulness", "manipulation, untapped talent, illusion"),
        major(2, "The High Priestess", "intuition, inner voice, hidden knowledge", "secrets kept from you, disconnected instincts"),
        major(3, "The Empress", "nurture, abundance, creativity", "creative block, smothering, dependence"),
        major(4, "The Emperor", "structure, authority, stability", "rigidity, domination, lack of discipline"),
        major(5, "The Hierophant", "tradition, guidance, shared beliefs", "rebellion, unconventionality, restriction"),
        major(6, "The Lovers", "union, alignment, meaningful choice", "disharmony, imbalance, misaligned values"),
        major(7, "The Chariot", "determination, momentum, victory through will", "lack of direction, opposition, burnout"),
        major(8, "Strength", "quiet courage, compassion, self-mastery", "self-doubt, raw emotion, weakness of resolve"),
        major(9, "The Hermit", "solitude, introspection, inner guidance", "isolation, withdrawal, lost direction"),
        major(10, "Wheel of Fortune", "cycles, turning points, fate in motion", "resistance to change, bad luck, broken cycles"),
        major(11, "Justice", "fairness, truth, cause and effect", "unfairness, avoidance of accountability"),
        major(12, "The Hanged Man", "surrender, new perspective, sacred pause", "stalling, resistance, needless sacrifice"),
        major(13, "Death", "endings, transformation, release", "clinging on, fear of change, stagnation"),
        major(14, "Temperance", "balance, patience, blending opposites", "excess, imbalance, misalignment"),
        major(15, "The Devil", "attachment, temptation, shadow self", "release, reclaiming power, facing the shadow"),
        major(16, "The Tower", "sudden upheaval, revelation, awakening", "averted disaster, fear of collapse, delayed reckoning"),
        major(17, "The Star", "hope, renewal, quiet faith", "discouragement, dimmed faith, disconnection"),
        major(18, "The Moon", "intuition, dreams, the subconscious", "confusion lifting, fear released, clarity emerging"),
        major(19, "The Sun", "joy, vitality, success in the open", "clouded optimism, delayed joy, dimmed vitality"),
        major(20, "Judgement", "reckoning, awakening, absolution", "self-doubt, harsh self-judgement, ignoring the call"),
        major(21, "The World", "completion, wholeness, arrival", "loose ends, incompletion, delayed closure"),
    ]

    static let minors: [TarotCard] =
        suitCards(.wands, [
            "inspiration, a spark, creative ignition", "false starts, delays, scattered energy",
            "planning, future vision, decisions ahead", "fear of the unknown, playing safe",
            "expansion, foresight, first results", "obstacles to plans, restlessness",
            "celebration, homecoming, milestones", "instability at home, transition",
            "friction, competition, creative tension", "avoided conflict, inner conflict",
            "victory, recognition, progress", "self-doubt, lack of recognition",
            "perseverance, defending ground", "exhaustion, feeling overwhelmed",
            "swift movement, momentum, news", "delays, frustration, resisting change",
            "resilience, last stand, boundaries", "paranoia, fatigue, defensiveness",
            "burden, responsibility, final push", "burnout, carrying too much",
            "curiosity, enthusiasm, a messenger", "hasty starts, scattered enthusiasm",
            "adventure, impulsive energy, passion", "haste, recklessness, delays",
            "warmth, confidence, magnetic vision", "demanding energy, jealousy",
            "leadership, bold vision, mastery", "impulsiveness, domineering will",
        ]) +
        suitCards(.cups, [
            "new feelings, open heart, emotional beginnings", "blocked feelings, emptiness",
            "partnership, mutual attraction, connection", "imbalance, broken bond, tension",
            "friendship, celebration, community", "overindulgence, gossip, isolation",
            "apathy, contemplation, missed offers", "renewed motivation, awareness",
            "loss, grief, focusing on what's gone", "acceptance, moving forward",
            "nostalgia, childhood memories, reunion", "living in the past, rose-tinting",
            "choices, fantasy, wishful thinking", "clarity of choice, disillusionment",
            "walking away, seeking deeper meaning", "fear of change, aimless drifting",
            "contentment, wishes fulfilled, satisfaction", "smugness, unfulfilled wishes",
            "harmony, family joy, emotional completion", "broken harmony, misaligned home",
            "creative openings, gentle messages, wonder", "emotional immaturity, escapism",
            "romance, charm, following the heart", "moodiness, unrealistic ideals",
            "compassion, calm depth, emotional security", "emotional overwhelm, martyrdom",
            "emotional mastery, diplomacy, balance", "manipulation, repressed feeling",
        ]) +
        suitCards(.swords, [
            "breakthrough, clarity, truth cutting through", "confusion, brutal truths, fog",
            "stalemate, difficult choice, blocked feelings", "indecision lifting, information revealed",
            "heartbreak, painful truth, sorrow", "healing, forgiveness, releasing pain",
            "rest, recovery, contemplation", "restlessness, burnout, stalled recovery",
            "hollow victory, conflict, discord", "reconciliation, making amends",
            "transition, moving on, calmer waters", "resistance to moving on, baggage",
            "strategy, stealth, acting alone", "confession, coming clean, conscience",
            "restriction, self-imposed limits, feeling trapped", "release, new perspective, freedom",
            "anxiety, sleepless nights, worry spirals", "hope returning, facing fears",
            "painful ending, rock bottom, betrayal", "recovery, the worst is over",
            "curiosity, mental agility, new ideas", "scattered thoughts, gossip",
            "ambition, drive, charging ahead", "impulsiveness, burnout, scattered force",
            "clear-eyed wisdom, independence, candour", "coldness, bitterness, harsh words",
            "intellect, authority, clear judgement", "abuse of power, cold logic",
        ]) +
        suitCards(.pentacles, [
            "opportunity, prosperity, tangible beginnings", "missed opportunity, poor planning",
            "balance in motion, juggling priorities", "overcommitment, dropped balls",
            "collaboration, craftsmanship, learning", "misalignment, lack of teamwork",
            "security, holding on, conservation", "letting go, generosity, loosened grip",
            "hardship, feeling left out, lean times", "recovery, doors reopening",
            "generosity, giving and receiving, support", "strings attached, one-sided giving",
            "patience, long-term view, investment", "impatience, wasted effort",
            "diligence, skill-building, steady work", "perfectionism, uninspired repetition",
            "independence, earned comfort, self-reliance", "over-work, fragile security",
            "legacy, family wealth, lasting foundations", "instability, family disputes",
            "studiousness, new skills, manifestation", "procrastination, lack of progress",
            "reliability, routine, methodical effort", "stagnation, boredom, obstinacy",
            "warm practicality, nurture, resourcefulness", "self-neglect, imbalance of care",
            "abundance, security, worldly success", "greed, materialism, poor judgement",
        ])

    static let all: [TarotCard] = majors + minors

    // MARK: builders

    private static func major(_ n: Int, _ name: String, _ up: String, _ rev: String) -> TarotCard {
        TarotCard(id: "major-\(n)", name: name, arcana: .major, number: n, suit: nil,
                  uprightKeywords: up, reversedKeywords: rev)
    }

    /// `keywords` is 28 strings: [up1, rev1, up2, rev2, … up14, rev14].
    private static func suitCards(_ suit: TarotCard.Suit, _ keywords: [String]) -> [TarotCard] {
        precondition(keywords.count == 28, "need 14 upright/reversed pairs for \(suit)")
        return (1...14).map { rank in
            let name: String
            let rankName = TarotCard(id: "", name: "", arcana: .minor, number: rank, suit: suit,
                                     uprightKeywords: "", reversedKeywords: "").numeral
            name = "\(rankName) of \(suit.displayName)"
            return TarotCard(
                id: "\(suit.rawValue)-\(rank)", name: name, arcana: .minor,
                number: rank, suit: suit,
                uprightKeywords: keywords[(rank - 1) * 2],
                reversedKeywords: keywords[(rank - 1) * 2 + 1]
            )
        }
    }
}
