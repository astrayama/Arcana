import Foundation

/// Central configuration for the Arcana app.
///
/// Supabase credentials are read from `Secrets.plist` (bundled, git-ignored) if present,
/// otherwise from the placeholders below. When no valid credentials are found the app
/// runs against `MockRepository` with seeded sample data so it is demoable immediately.
enum AppConfig {

    // MARK: - Supabase

    /// Fill these in (or drop a `Secrets.plist` with `SUPABASE_URL` / `SUPABASE_ANON_KEY`)
    /// to wire the app to your existing web account's Supabase project.
    static let supabaseURLString = secret("SUPABASE_URL") ?? "https://YOUR-PROJECT.supabase.co"
    static let supabaseAnonKey   = secret("SUPABASE_ANON_KEY") ?? "YOUR-ANON-KEY"

    /// True when real Supabase credentials have been supplied.
    static var hasSupabase: Bool {
        !supabaseURLString.contains("YOUR-PROJECT") &&
        !supabaseAnonKey.contains("YOUR-ANON-KEY") &&
        URL(string: supabaseURLString) != nil
    }

    // MARK: - App group (shared with widgets)

    static let appGroupIdentifier = "group.com.arcana.shared"
    static let urlScheme = "arcana"

    // MARK: - Secrets.plist loader

    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return dict
    }()

    private static func secret(_ key: String) -> String? {
        (secrets[key] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}
