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
            store = Store()
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
