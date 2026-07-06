import SwiftUI

/// Journal — wireframe 2d. A month is a ledger page: stats header, ruled rows
/// (cards + spreads mixed), swipe to flip months.
struct JournalView: View {
    @EnvironmentObject private var store: AppStore

    @State private var month = Calendar.current.startOfMonth(for: Date())
    @State private var filter: JournalFilter = .all
    @State private var searching = false
    @State private var query = ""
    @State private var flipDirection: Edge = .trailing

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                monthHeader
                statsPanel
                filterRow
                ledgerPage
                footerHint
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 108)
            .background {
                Arcana.CosmosBackground()
                StarfieldView()
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: Month header ‹ July ›

    private var monthHeader: some View {
        HStack {
            Button { flip(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Arcana.Palette.muted)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            VStack(spacing: 0) {
                Text(month.formatted(.dateTime.month(.wide)))
                    .displayFont(30)
                    .foregroundStyle(Arcana.brandGradient)
                Text(month.formatted(.dateTime.year()))
                    .bodyFont(12)
                    .kerning(2.4)
                    .foregroundStyle(Arcana.Palette.muted)
            }
            Spacer()
            Button { flip(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(canGoForward ? Arcana.Palette.muted : Arcana.Palette.muted.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            .disabled(!canGoForward)
        }
    }

    private var canGoForward: Bool {
        month < Calendar.current.startOfMonth(for: Date())
    }

    private func flip(by delta: Int) {
        guard delta < 0 || canGoForward else { return }
        Haptics.tick()
        flipDirection = delta > 0 ? .trailing : .leading
        withAnimation(.snappy(duration: 0.35)) {
            month = Calendar.current.date(byAdding: .month, value: delta, to: month)!
        }
    }

    // MARK: Stats header — streaks live here, per the user's call

    private var statsPanel: some View {
        let stats = store.stats(forMonthOf: month)
        return HStack(spacing: 0) {
            stat(value: "✦ \(stats.streakDays)", label: "DAY STREAK", color: Arcana.Palette.gold)
            divider
            stat(value: "\(stats.cardCount)", label: "CARDS", color: Arcana.Palette.text)
            divider
            stat(value: "\(stats.spreadCount)", label: "SPREADS", color: Arcana.Palette.blue)
        }
        .padding(.vertical, 13)
        .glass()
    }

    private var divider: some View {
        Rectangle().fill(Arcana.Palette.hairline).frame(width: 1, height: 30)
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .bodyFont(17, weight: .heavy)
                .foregroundStyle(color)
            Text(label)
                .bodyFont(10.5)
                .foregroundStyle(Arcana.Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Filters + search

    private var filterRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach(JournalFilter.allCases, id: \.self) { f in
                    Chip(label: f.rawValue, isOn: filter == f) {
                        Haptics.tick()
                        withAnimation(.snappy) { filter = f }
                    }
                }
                Spacer()
                Chip(label: "⌕", isOn: searching) {
                    withAnimation(.snappy) {
                        searching.toggle()
                        if !searching { query = "" }
                    }
                }
            }
            if searching {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Arcana.Palette.muted)
                    TextField("Search cards, notes, spreads…", text: $query)
                        .bodyFont(14)
                        .foregroundStyle(Arcana.Palette.text)
                        .autocorrectionDisabled()
                }
                .glassField()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Ledger page

    private var entries: [JournalEntry] {
        var rows = store.entries(inMonthOf: month, filter: filter)
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            rows = rows.filter { entry in
                switch entry {
                case .pull(let p):
                    let card = Deck.card(id: p.cardID)
                    return (card?.name.lowercased().contains(q) ?? false)
                        || p.note.lowercased().contains(q)
                case .spread(let s):
                    return s.title.lowercased().contains(q)
                        || s.note.lowercased().contains(q)
                        || s.cards.contains {
                            Deck.card(id: $0.cardID)?.name.lowercased().contains(q) ?? false
                        }
                }
            }
        }
        return rows
    }

    private var ledgerPage: some View {
        Group {
            if entries.isEmpty {
                VStack(spacing: 10) {
                    Text("☾")
                        .font(.system(size: 34))
                        .foregroundStyle(Arcana.Palette.faint)
                    Text(query.isEmpty ? "No entries this month" : "Nothing matches")
                        .bodyFont(14, weight: .semibold)
                        .foregroundStyle(Arcana.Palette.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glass()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            NavigationLink {
                                switch entry {
                                case .pull(let p): CardDetailView(pull: p)
                                case .spread(let s): SpreadDetailView(spread: s)
                                }
                            } label: {
                                JournalRow(entry: entry, isLast: index == entries.count - 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .glass()
            }
        }
        .frame(maxHeight: .infinity)
        .id(month)   // re-created per month so the flip transition runs
        .transition(.asymmetric(
            insertion: .move(edge: flipDirection).combined(with: .opacity),
            removal: .opacity
        ))
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -50 { flip(by: 1) }
                    if value.translation.width > 50 { flip(by: -1) }
                }
        )
    }

    private var footerHint: some View {
        VStack(spacing: 5) {
            Text("‹ swipe to flip months ›")
                .bodyFont(12)
                .foregroundStyle(Arcana.Palette.muted)
            HStack(spacing: 8) {
                ForEach(-1...1, id: \.self) { offset in
                    Circle()
                        .fill(offset == 0 ? Arcana.Palette.purple : Color(hex: 0x4A4360))
                        .frame(width: 5, height: 5)
                }
            }
        }
    }
}

// MARK: - Ledger row (`.jrow`)

private struct JournalRow: View {
    let entry: JournalEntry
    var isLast = false

    var body: some View {
        HStack(spacing: 12) {
            // Date column
            VStack(spacing: 0) {
                Text(entry.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .bodyFont(10.5)
                    .foregroundStyle(Arcana.Palette.muted)
                Text(entry.date.formatted(.dateTime.day()))
                    .bodyFont(15, weight: .bold)
                    .foregroundStyle(Arcana.Palette.text)
            }
            .frame(width: 40)

            thumbnails

            VStack(alignment: .leading, spacing: 2) {
                title
                subtitle
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Arcana.Palette.faint)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            if !isLast {
                RuledLine()
                    .stroke(Arcana.Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .frame(height: 1)
                    .padding(.horizontal, 14)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnails: some View {
        switch entry {
        case .pull(let p):
            if let card = Deck.card(id: p.cardID) {
                CardArtView(card: card, orientation: p.orientation)
                    .frame(width: 30, height: 50)
            }
        case .spread(let s):
            // Overlapping thumbs, like the wireframe's spread rows.
            HStack(spacing: -14) {
                ForEach(s.cards.prefix(3)) { placed in
                    if let card = Deck.card(id: placed.cardID) {
                        CardArtView(card: card, orientation: placed.orientation)
                            .frame(width: 30, height: 50)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var title: some View {
        switch entry {
        case .pull(let p):
            if let card = Deck.card(id: p.cardID) {
                (Text(card.name).foregroundColor(Arcana.Palette.text)
                 + Text("  \(p.orientation.arrow)")
                    .foregroundColor(p.orientation == .upright
                                     ? Arcana.Palette.gold : Arcana.Palette.blue))
                    .bodyFont(14, weight: .bold)
            }
        case .spread(let s):
            Text(s.title)
                .bodyFont(14, weight: .bold)
                .foregroundStyle(Arcana.Palette.blueSoft)
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        switch entry {
        case .pull(let p):
            Text(p.note.isEmpty ? "quiet day, no notes" : p.note)
                .bodyFont(12)
                .foregroundStyle(Arcana.Palette.muted)
                .lineLimit(1)
        case .spread(let s):
            Text(s.templateName)
                .bodyFont(12)
                .foregroundStyle(Arcana.Palette.muted)
                .lineLimit(1)
        }
    }
}

/// A straight ruled line (Shape so it can take a dashed stroke style).
private struct RuledLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Calendar helper

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date))!
    }
}
