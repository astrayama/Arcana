import SwiftUI

/// Home — wireframe 2a. One glance: today's card, spreads entry, quiet streak link.
struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var session: SessionStore

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    if let pull = store.todayPull, let card = Deck.card(id: pull.cardID) {
                        NavigationLink {
                            CardDetailView(pull: pull)
                        } label: {
                            TodayCardPanel(pull: pull, card: card)
                        }
                        .buttonStyle(.plain)
                    } else {
                        EmptyTodayPanel { router.showQuickLog = true }
                    }

                    spreadsRow
                    streakRow
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
            .background {
                Arcana.CosmosBackground()
                StarfieldView()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .displayFont(36)
                    .foregroundStyle(Arcana.Palette.text)
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .bodyFont(14)
                    .foregroundStyle(Arcana.Palette.muted)
            }
            Spacer()
            // Settings tucked behind the avatar, per wireframe 1b.
            Button { showSettings = true } label: {
                Circle()
                    .fill(LinearGradient(colors: [Arcana.Palette.purple, Arcana.Palette.blue],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(avatarInitial)
                            .bodyFont(15, weight: .heavy)
                            .foregroundStyle(Color(hex: 0x120C1E))
                    )
            }
            .accessibilityLabel("Profile & settings")
        }
    }

    private var avatarInitial: String {
        String(session.userEmail?.first.map(String.init)?.uppercased() ?? "A")
    }

    // MARK: Spreads entry row

    private var spreadsRow: some View {
        NavigationLink {
            SpreadsHomeView()
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Arcana.Palette.blue.opacity(0.14))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Arcana.Palette.blue.opacity(0.35), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "rectangle.grid.3x1")
                            .font(.system(size: 17))
                            .foregroundStyle(Arcana.Palette.blue)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tarot Spreads")
                        .bodyFont(16, weight: .bold)
                        .foregroundStyle(Arcana.Palette.text)
                    Text("Start a reading — 3-card, Celtic Cross, custom")
                        .bodyFont(12.5)
                        .foregroundStyle(Arcana.Palette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Arcana.Palette.muted)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .glass()
        }
        .buttonStyle(.plain)
    }

    // MARK: Streak row (quiet — full stats live in the journal)

    private var streakRow: some View {
        Button {
            withAnimation(.snappy) { router.tab = .journal }
        } label: {
            HStack(spacing: 12) {
                SparkleText(size: 16)
                Text(streakText)
                    .bodyFont(13.5, weight: .semibold)
                    .foregroundStyle(Arcana.Palette.muted)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Arcana.Palette.muted)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .glass()
        }
        .buttonStyle(.plain)
    }

    private var streakText: String {
        let streak = store.currentStreak()
        return streak > 0
            ? "\(streak)-day streak — full stats in your journal"
            : "Start a streak — your ledger is waiting"
    }
}

// MARK: - Today's card panel (logged state)

private struct TodayCardPanel: View {
    let pull: CardPull
    let card: TarotCard

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                CardArtView(card: card, orientation: pull.orientation)
                    .frame(width: 106, height: 178)
                    .floating()
                    .goldGlow()

                VStack(alignment: .leading, spacing: 0) {
                    Text("TODAY'S CARD")
                        .bodyFont(10.5, weight: .bold)
                        .kerning(1.6)
                        .foregroundStyle(Arcana.Palette.gold)
                    Text(card.name)
                        .displayFont(27)
                        .foregroundStyle(Arcana.Palette.text)
                        .padding(.top, 4)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                    Text("\(pull.orientation.label) · \(card.arcana == .major ? "Major Arcana" : card.subtitle)")
                        .bodyFont(13)
                        .foregroundStyle(Arcana.Palette.muted)
                        .padding(.top, 2)
                    if !pull.note.isEmpty {
                        Text("“\(pull.note)”")
                            .bodyFont(13)
                            .italic()
                            .foregroundStyle(Arcana.Palette.muted)
                            .lineSpacing(4)
                            .lineLimit(3)
                            .padding(.top, 10)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: 178)
            }
            .padding(18)

            Divider().overlay(Arcana.Palette.hairline)

            // AI insight, collapsed by default — never blocks the flow.
            InsightRow(pull: pull, card: card)
        }
        .glass(stroke: Arcana.Palette.gold.opacity(0.35))
    }
}

/// Inline collapsed insight footer inside the today panel.
private struct InsightRow: View {
    let pull: CardPull
    let card: TarotCard
    @State private var expanded = false
    @State private var insight: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SparkleText(size: 13, color: Arcana.Palette.purpleSoft)
                Text("AI insight")
                    .bodyFont(13, weight: .bold)
                    .foregroundStyle(Arcana.Palette.purpleSoft)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Arcana.Palette.faint)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            if expanded {
                Text(insight ?? "Reading the card…")
                    .bodyFont(13)
                    .foregroundStyle(Arcana.Palette.muted)
                    .lineSpacing(4)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.3)) { expanded.toggle() }
            if insight == nil {
                Task {
                    if let cached = pull.insight {
                        insight = cached
                    } else {
                        insight = await InsightService.insight(
                            for: card, orientation: pull.orientation, note: pull.note
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Empty state (not logged yet)

private struct EmptyTodayPanel: View {
    var logAction: () -> Void

    var body: some View {
        Button(action: logAction) {
            VStack(spacing: 14) {
                CardBackView()
                    .frame(width: 96, height: 160)
                    .floating(amplitude: 4)
                Text("No card yet today")
                    .displayFont(22)
                    .foregroundStyle(Arcana.Palette.text)
                Text("Tap to log today's pull — it takes ten seconds.")
                    .bodyFont(13)
                    .foregroundStyle(Arcana.Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .glass(stroke: Arcana.Palette.gold.opacity(0.35))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
