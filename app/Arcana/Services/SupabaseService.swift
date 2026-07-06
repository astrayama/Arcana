import Foundation
import Supabase

/// Shared Supabase client. Only constructed when real credentials exist.
enum SupabaseService {
    static let client: SupabaseClient? = {
        guard AppConfig.hasSupabase, let url = URL(string: AppConfig.supabaseURLString) else {
            return nil
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: AppConfig.supabaseAnonKey)
    }()
}

// MARK: - Supabase repository

/// Persists pulls & spreads to Supabase (schema in `app/supabase/schema.sql`).
/// All tables are protected by row-level security keyed on `auth.uid()`.
final class SupabaseRepository: ArcanaRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    // Row shapes (snake_case) ------------------------------------------------

    private struct PullRow: Codable {
        var id: UUID
        var user_id: UUID?
        var card_id: String
        var orientation: String
        var note: String
        var date: Date
        var insight: String?
        var created_at: Date?

        init(_ p: CardPull, userID: UUID?) {
            id = p.id; user_id = userID; card_id = p.cardID
            orientation = p.orientation.rawValue
            note = p.note; date = p.date; insight = p.insight; created_at = p.createdAt
        }

        var model: CardPull {
            CardPull(id: id, cardID: card_id,
                     orientation: Orientation(rawValue: orientation) ?? .upright,
                     note: note, date: date, insight: insight,
                     createdAt: created_at ?? date)
        }
    }

    private struct SpreadRow: Codable {
        var id: UUID
        var user_id: UUID?
        var title: String
        var template_id: String
        var template_name: String
        var cards: [SpreadCard]
        var note: String
        var date: Date
        var insight: String?
        var created_at: Date?

        init(_ s: Spread, userID: UUID?) {
            id = s.id; user_id = userID; title = s.title
            template_id = s.templateID; template_name = s.templateName
            cards = s.cards; note = s.note; date = s.date
            insight = s.insight; created_at = s.createdAt
        }

        var model: Spread {
            Spread(id: id, title: title, templateID: template_id,
                   templateName: template_name, cards: cards, note: note,
                   date: date, insight: insight, createdAt: created_at ?? date)
        }
    }

    // Queries ----------------------------------------------------------------

    private var userID: UUID? {
        get async { try? await client.auth.session.user.id }
    }

    func fetchPulls() async throws -> [CardPull] {
        let rows: [PullRow] = try await client.from("pulls")
            .select().order("date", ascending: false)
            .execute().value
        return rows.map(\.model)
    }

    func fetchSpreads() async throws -> [Spread] {
        let rows: [SpreadRow] = try await client.from("spreads")
            .select().order("date", ascending: false)
            .execute().value
        return rows.map(\.model)
    }

    func save(_ pull: CardPull) async throws {
        try await client.from("pulls")
            .upsert(PullRow(pull, userID: await userID))
            .execute()
    }

    func save(_ spread: Spread) async throws {
        try await client.from("spreads")
            .upsert(SpreadRow(spread, userID: await userID))
            .execute()
    }

    func deletePull(id: UUID) async throws {
        try await client.from("pulls").delete().eq("id", value: id).execute()
    }

    func deleteSpread(id: UUID) async throws {
        try await client.from("spreads").delete().eq("id", value: id).execute()
    }
}
