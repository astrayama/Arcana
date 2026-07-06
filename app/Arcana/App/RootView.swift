import SwiftUI

/// The 3-slot shell from wireframe 1b/2a: Today · center ⊕ log · Journal,
/// rendered as a floating frosted pill.
struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var router: Router

    var body: some View {
        ZStack(alignment: .bottom) {
            Arcana.CosmosBackground()
            StarfieldView()

            Group {
                switch router.tab {
                case .today: TodayView()
                case .journal: JournalView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar()
        }
        .sheet(isPresented: $router.showQuickLog) {
            if store.hasLoggedFirstEntry {
                QuickLogSheet()
            } else {
                GuidedFirstEntryFlow()
            }
        }
        .fullScreenCover(isPresented: $router.showDraw) {
            DrawView()
        }
        .sheet(isPresented: $router.showSpreadBuilder) {
            SpreadBuilderFlow()
        }
    }
}

// MARK: - Floating tab bar (`.htab` + `.plus`)

private struct TabBar: View {
    @EnvironmentObject private var router: Router

    var body: some View {
        HStack {
            tabItem(.today, glyph: "moon.fill", label: "Today")

            // Center ⊕ — one thumb-reach log button.
            Button {
                Haptics.tick()
                router.showQuickLog = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Arcana.purpleGradient)
                        .frame(width: 60, height: 60)
                        .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: Arcana.Palette.purple.opacity(0.45), radius: 13)
                        .shadow(color: .black.opacity(0.45), radius: 11, y: 10)
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color(hex: 0x120C1E))
                }
            }
            .offset(y: -22)
            .accessibilityLabel("Log a card")

            tabItem(.journal, glyph: "square.grid.2x2.fill", label: "Journal")
        }
        .frame(height: 64)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(Color(hex: 0x100E1A).opacity(0.74))
                .background(Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
        )
        .overlay(Capsule().strokeBorder(Arcana.Palette.glassStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private func tabItem(_ tab: Router.Tab, glyph: String, label: String) -> some View {
        let isOn = router.tab == tab
        return Button {
            if !isOn { Haptics.tick() }
            withAnimation(.snappy(duration: 0.25)) { router.tab = tab }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: glyph).font(.system(size: 19))
                Text(label).bodyFont(10, weight: .bold)
            }
            .foregroundStyle(isOn ? Arcana.Palette.purple : Arcana.Palette.faint)
            .frame(width: 84)
        }
        .buttonStyle(.plain)
    }
}
