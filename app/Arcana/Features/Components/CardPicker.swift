import SwiftUI

/// Search-as-you-type picker over all 78 cards. Shared by the quick-log sheet,
/// guided first entry, and the spread builder.
struct CardPicker: View {
    @Binding var selectedCardID: String?
    var placeholder = "Search 78 cards"

    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [TarotCard] { Deck.search(query) }
    private var selected: TarotCard? { selectedCardID.flatMap(Deck.card(id:)) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Arcana.Palette.muted)
                TextField(placeholder, text: $query)
                    .bodyFont(14)
                    .foregroundStyle(Arcana.Palette.text)
                    .focused($focused)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Arcana.Palette.faint)
                    }
                }
            }
            .glassField()

            if let selected {
                SelectedCardRow(card: selected)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(results.prefix(30)) { card in
                            Button {
                                Haptics.tick()
                                withAnimation(.snappy(duration: 0.25)) {
                                    selectedCardID = card.id
                                }
                                focused = false
                            } label: {
                                HStack(spacing: 12) {
                                    CardArtView(card: card)
                                        .frame(width: 30, height: 50)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(card.name)
                                            .bodyFont(14, weight: .bold)
                                            .foregroundStyle(Arcana.Palette.text)
                                        Text(card.subtitle)
                                            .bodyFont(11.5)
                                            .foregroundStyle(Arcana.Palette.muted)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
    }
}

/// The confirmed-selection row (`2b`): art, name, numeral, gold check.
struct SelectedCardRow: View {
    let card: TarotCard
    var orientation: Orientation = .upright

    var body: some View {
        HStack(spacing: 12) {
            CardArtView(card: card, orientation: orientation)
                .frame(width: 40, height: 67)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .bodyFont(14, weight: .bold)
                    .foregroundStyle(Arcana.Palette.text)
                Text(card.subtitle)
                    .bodyFont(12)
                    .foregroundStyle(Arcana.Palette.muted)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Arcana.Palette.gold)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Arcana.Palette.purple.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Arcana.Palette.purple.opacity(0.4), lineWidth: 1)
        )
    }
}
