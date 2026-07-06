import SwiftUI

@main
struct ArcanaApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var store = AppStore()
    @StateObject private var router = Router()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.state == .loading {
                    ZStack {
                        Arcana.CosmosBackground()
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Arcana.Palette.purple)
                    }
                } else if store.hasOnboarded && session.state != .signedOut {
                    RootView()
                } else {
                    // One branch for every pre-app state, so signing in mid-flow
                    // doesn't recreate the onboarding and lose the page position.
                    OnboardingFlow()
                }
            }
            .environmentObject(session)
            .environmentObject(store)
            .environmentObject(router)
            .preferredColorScheme(.dark)
            .tint(Arcana.Palette.purple)
            .task { await store.load() }
            .onChange(of: session.state) { _, newState in
                // Re-fetch once auth lands so RLS-scoped rows appear.
                if newState == .signedIn {
                    Task { await store.load() }
                }
            }
            .onOpenURL { url in router.handle(url) }
        }
    }
}

/// App-wide navigation intents, including widget deep links
/// (`arcana://log`, `arcana://today`, `arcana://journal`).
@MainActor
final class Router: ObservableObject {
    enum Tab: Hashable { case today, journal }

    @Published var tab: Tab = .today
    @Published var showQuickLog = false
    @Published var showDraw = false
    @Published var showSpreadBuilder = false

    /// Set by the draw flow ("Journal it") so the quick-log sheet opens pre-filled.
    @Published var prefillCardID: String?
    @Published var prefillOrientation: Orientation?

    /// Template chosen on the spreads screen; nil means custom.
    @Published var spreadBuilderTemplate: SpreadTemplate? = .threeCard

    func consumePrefill() -> (String, Orientation)? {
        defer { prefillCardID = nil; prefillOrientation = nil }
        guard let id = prefillCardID else { return nil }
        return (id, prefillOrientation ?? .upright)
    }

    func handle(_ url: URL) {
        guard url.scheme == AppConfig.urlScheme else { return }
        switch url.host {
        case "log":
            tab = .today
            showQuickLog = true
        case "journal":
            tab = .journal
        default:
            tab = .today
        }
    }
}
