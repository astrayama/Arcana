import Foundation

/// Generates the collapsible "✦ AI insight" text.
///
/// By default this composes a reflective reading locally from the card's keyword
/// data, so the feature works offline and without any API key. To use a real
/// model, point `remoteEndpoint` at a Supabase Edge Function (or any HTTPS
/// endpoint) that accepts `{card, orientation, note}` and returns `{insight}` —
/// the local composer stays as the fallback.
enum InsightService {

    /// Optional remote insight endpoint (e.g. a Supabase Edge Function URL).
    static var remoteEndpoint: URL? = nil

    static func insight(for card: TarotCard, orientation: Orientation, note: String) async -> String {
        if let remote = await fetchRemote(card: card, orientation: orientation, note: note) {
            return remote
        }
        return composeLocally(card: card, orientation: orientation, note: note)
    }

    static func insight(for spread: Spread) async -> String {
        let lines: [String] = spread.cards.compactMap { placed in
            guard let card = Deck.card(id: placed.cardID) else { return nil }
            let keywords = placed.orientation == .upright ? card.uprightKeywords : card.reversedKeywords
            return "\(placed.position) — \(card.name) \(placed.orientation.arrow): \(keywords)."
        }
        let arc = "Read together, the spread traces an arc from \(spread.cards.first?.position.lowercased() ?? "beginning") to \(spread.cards.last?.position.lowercased() ?? "end") — notice which card pulls your eye first; that position is usually where the real question lives."
        return (lines + [arc]).joined(separator: "\n")
    }

    // MARK: local composer

    private static func composeLocally(card: TarotCard, orientation: Orientation, note: String) -> String {
        let keywords = orientation == .upright ? card.uprightKeywords : card.reversedKeywords
        let stance = orientation == .upright
            ? "\(orientation.label), \(card.name) speaks to \(keywords)."
            : "Reversed, \(card.name) turns inward — \(keywords)."
        let prompt: String
        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt = "Where might this show up in your day? Note the first situation that comes to mind — that's usually the one."
        } else {
            prompt = "Hold your note next to the card: where do the two agree, and where do they pull apart? The tension is the message."
        }
        return stance + " " + prompt
    }

    // MARK: remote (optional)

    private struct RemoteRequest: Codable {
        let card: String
        let orientation: String
        let note: String
    }
    private struct RemoteResponse: Codable { let insight: String }

    private static func fetchRemote(card: TarotCard, orientation: Orientation, note: String) async -> String? {
        guard let endpoint = remoteEndpoint else { return nil }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(
            RemoteRequest(card: card.name, orientation: orientation.rawValue, note: note)
        )
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(RemoteResponse.self, from: data)
        else { return nil }
        return decoded.insight
    }
}
