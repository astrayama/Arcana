import Foundation
import SwiftUI
import WidgetKit

/// Central observable state: journal data, stats, and cross-cutting flags.
@MainActor
final class AppStore: ObservableObject {

    @Published private(set) var pulls: [CardPull] = []
    @Published private(set) var spreads: [Spread] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// Persisted app flags, shared with the widget via the app group.
    /// (@Published + manual persistence — @AppStorage doesn't reliably publish
    /// from inside an ObservableObject.)
    static let defaults = UserDefaults(suiteName: AppConfig.appGroupIdentifier) ?? .standard

    @Published var hasOnboarded: Bool {
        didSet { Self.defaults.set(hasOnboarded, forKey: "hasOnboarded") }
    }
    @Published var hasLoggedFirstEntry: Bool {
        didSet { Self.defaults.set(hasLoggedFirstEntry, forKey: "hasLoggedFirstEntry") }
    }
    @Published var remindersEnabled: Bool {
        didSet { Self.defaults.set(remindersEnabled, forKey: "remindersEnabled") }
    }
    @Published var reminderHour: Int {
        didSet { Self.defaults.set(reminderHour, forKey: "reminderHour") }
    }
    @Published var reminderMinute: Int {
        didSet { Self.defaults.set(reminderMinute, forKey: "reminderMinute") }
    }

    private(set) var repository: ArcanaRepository

    init(repository: ArcanaRepository? = nil) {
        let d = Self.defaults
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        hasLoggedFirstEntry = d.bool(forKey: "hasLoggedFirstEntry")
        remindersEnabled = d.bool(forKey: "remindersEnabled")
        reminderHour = d.object(forKey: "reminderHour") as? Int ?? 21
        reminderMinute = d.object(forKey: "reminderMinute") as? Int ?? 0

        if let repository {
            self.repository = repository
        } else {
            self.repository = Self.makeDefaultRepository()
        }
    }

    /// Uses Supabase sync when the package is linked and configured, otherwise
    /// the seeded local ledger.
    private static func makeDefaultRepository() -> ArcanaRepository {
        #if canImport(Supabase)
        if let client = SupabaseService.client {
            return SupabaseRepository(client: client)
        }
        #endif
        return LocalRepository(seedDemoData: true)
    }

    // MARK: Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let p = repository.fetchPulls()
            async let s = repository.fetchSpreads()
            pulls = try await p
            spreads = try await s
            syncWidgetSnapshot()
        } catch {
            errorMessage = "Couldn't load your ledger — \(error.localizedDescription)"
        }
    }

    // MARK: Saving

    func save(_ pull: CardPull, haptic: Bool = true) async {
        let previousStreak = stats().streakDays
        do {
            try await repository.save(pull)
            pulls.removeAll { $0.id == pull.id }
            pulls.insert(pull, at: 0)
            pulls.sort { $0.date > $1.date }
            hasLoggedFirstEntry = true
            syncWidgetSnapshot()

            guard haptic else { return }
            let newStreak = stats().streakDays
            if newStreak > previousStreak, newStreak % 3 == 0 {
                Haptics.milestone()   // rigid on streak milestones
            } else {
                Haptics.soft()        // soft on save
            }
        } catch {
            errorMessage = "Couldn't save — \(error.localizedDescription)"
        }
    }

    func save(_ spread: Spread) async {
        do {
            try await repository.save(spread)
            spreads.removeAll { $0.id == spread.id }
            spreads.insert(spread, at: 0)
            spreads.sort { $0.date > $1.date }
            Haptics.soft()
            syncWidgetSnapshot()
        } catch {
            errorMessage = "Couldn't save — \(error.localizedDescription)"
        }
    }

    func delete(_ entry: JournalEntry) async {
        do {
            switch entry {
            case .pull(let p):
                try await repository.deletePull(id: p.id)
                pulls.removeAll { $0.id == p.id }
            case .spread(let s):
                try await repository.deleteSpread(id: s.id)
                spreads.removeAll { $0.id == s.id }
            }
            syncWidgetSnapshot()
        } catch {
            errorMessage = "Couldn't delete — \(error.localizedDescription)"
        }
    }

    func eraseAllLocalData() {
        (repository as? LocalRepository)?.eraseAll()
        pulls = []
        spreads = []
        hasLoggedFirstEntry = false
        syncWidgetSnapshot()
    }

    // MARK: Derived state

    /// Today's daily card, if one has been logged.
    var todayPull: CardPull? {
        pulls.first { Calendar.current.isDateInToday($0.date) }
    }

    /// Journal rows for a given month, newest first.
    func entries(inMonthOf date: Date, filter: JournalFilter = .all) -> [JournalEntry] {
        let cal = Calendar.current
        var rows: [JournalEntry] = []
        if filter != .spreads {
            rows += pulls
                .filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }
                .map(JournalEntry.pull)
        }
        if filter != .cards {
            rows += spreads
                .filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }
                .map(JournalEntry.spread)
        }
        return rows.sorted { $0.date > $1.date }
    }

    /// Streak plus per-month card/spread counts for the ledger header.
    func stats(forMonthOf date: Date = Date()) -> JournalStats {
        let cal = Calendar.current
        let cards = pulls.filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }.count
        let spreadCount = spreads.filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }.count
        return JournalStats(streakDays: currentStreak(), cardCount: cards, spreadCount: spreadCount)
    }

    /// Consecutive days (ending today or yesterday) with at least one entry.
    func currentStreak() -> Int {
        let cal = Calendar.current
        let days = Set(
            (pulls.map(\.date) + spreads.map(\.date)).map { cal.startOfDay(for: $0) }
        )
        guard !days.isEmpty else { return 0 }

        var cursor = cal.startOfDay(for: Date())
        // A streak survives until the end of today: if today isn't logged yet,
        // count back from yesterday.
        if !days.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
            guard days.contains(cursor) else { return 0 }
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    // MARK: Widget snapshot

    /// Writes the small state file the widget timeline reads.
    func syncWidgetSnapshot() {
        let todayCard = todayPull.flatMap { Deck.card(id: $0.cardID) }
        let snapshot = WidgetSnapshot(
            date: Date(),
            cardID: todayPull?.cardID,
            cardName: todayCard?.name,
            orientation: todayPull?.orientation.rawValue,
            streak: currentStreak(),
            imageURLString: todayCard.flatMap { CardArtView.remoteURL(for: $0)?.absoluteString }
        )
        WidgetSnapshot.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum JournalFilter: String, CaseIterable {
    case all = "All"
    case cards = "Cards"
    case spreads = "Spreads"
}

/// The tiny cross-process payload shared with the widget extension.
struct WidgetSnapshot: Codable {
    var date: Date
    var cardID: String?
    var cardName: String?
    var orientation: String?
    var streak: Int
    var imageURLString: String?

    static var fileURL: URL {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return container.appendingPathComponent("widget-snapshot.json")
    }

    static func write(_ snapshot: WidgetSnapshot) {
        if let data = try? JSONEncoder.arcana.encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    static func read() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder.arcana.decode(WidgetSnapshot.self, from: data)
    }
}
