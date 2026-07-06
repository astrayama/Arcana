import SwiftUI

/// Spreads landing — reached from the Today "Tarot Spreads" row.
/// Start a new reading from a template, or revisit recent spreads.
struct SpreadsHomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var router: Router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("START A READING")
                    .bodyFont(10.5, weight: .bold)
                    .kerning(1.6)
                    .foregroundStyle(Arcana.Palette.muted)

                VStack(spacing: 0) {
                    ForEach(Array(SpreadTemplate.builtIn.enumerated()), id: \.element.id) { index, template in
                        Button {
                            router.spreadBuilderTemplate = template
                            router.showSpreadBuilder = true
                        } label: {
                            TemplateRow(template: template,
                                        isLast: index == SpreadTemplate.builtIn.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        router.spreadBuilderTemplate = nil   // custom
                        router.showSpreadBuilder = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(Arcana.Palette.purpleSoft)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Custom spread")
                                    .bodyFont(14, weight: .bold)
                                    .foregroundStyle(Arcana.Palette.text)
                                Text("Name your own positions")
                                    .bodyFont(12)
                                    .foregroundStyle(Arcana.Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Arcana.Palette.faint)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .glass()

                if !store.spreads.isEmpty {
                    Text("RECENT SPREADS")
                        .bodyFont(10.5, weight: .bold)
                        .kerning(1.6)
                        .foregroundStyle(Arcana.Palette.muted)
                        .padding(.top, 8)

                    VStack(spacing: 10) {
                        ForEach(store.spreads.prefix(6)) { spread in
                            NavigationLink {
                                SpreadDetailView(spread: spread)
                            } label: {
                                RecentSpreadCard(spread: spread)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
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
        .navigationTitle("Tarot Spreads")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct TemplateRow: View {
    let template: SpreadTemplate
    var isLast = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(0..<min(template.positions.count, 3), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Arcana.Palette.gold.opacity(0.5), lineWidth: 1)
                        .frame(width: 9, height: 15)
                }
            }
            .frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(template.name)
                    .bodyFont(14, weight: .bold)
                    .foregroundStyle(Arcana.Palette.text)
                Text("\(template.positions.count) card\(template.positions.count == 1 ? "" : "s")")
                    .bodyFont(12)
                    .foregroundStyle(Arcana.Palette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Arcana.Palette.faint)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Arcana.Palette.hairline).frame(height: 0.7)
                    .padding(.leading, 56)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct RecentSpreadCard: View {
    let spread: Spread

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: -14) {
                ForEach(spread.cards.prefix(3)) { placed in
                    if let card = Deck.card(id: placed.cardID) {
                        CardArtView(card: card, orientation: placed.orientation)
                            .frame(width: 32, height: 53)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(spread.title)
                    .bodyFont(14, weight: .bold)
                    .foregroundStyle(Arcana.Palette.blueSoft)
                Text("\(spread.date.formatted(.dateTime.month(.wide).day())) · \(spread.templateName)")
                    .bodyFont(12)
                    .foregroundStyle(Arcana.Palette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Arcana.Palette.faint)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glass()
    }
}
