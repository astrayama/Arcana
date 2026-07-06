import SwiftUI

/// Spread detail — wireframe 2e. Cards stagger-fade in, notes below,
/// collapsible full-spread insight, and the gold export button.
struct SpreadDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let spread: Spread

    @State private var appeared = false
    @State private var confirmDelete = false
    @State private var showExport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                cardsPanel
                if !spread.note.isEmpty { notesPanel }
                InsightDisclosure(title: "Full spread insight") {
                    await InsightService.insight(for: spread)
                }
                GoldButton(title: "↥ Export spread") { showExport = true }
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background {
            Arcana.CosmosBackground()
            StarfieldView()
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation { appeared = true }
        }
        .confirmationDialog("Delete this spread from your ledger?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await store.delete(.spread(spread))
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showExport) {
            ExportView(spread: spread)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Arcana.Palette.muted)
                    .frame(width: 38, height: 44)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(spread.title)
                    .displayFont(25)
                    .foregroundStyle(Arcana.Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(spread.date.formatted(.dateTime.month(.wide).day())) · \(spread.templateName)")
                    .bodyFont(12.5)
                    .foregroundStyle(Arcana.Palette.muted)
            }
            Spacer()
            Menu {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete spread", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17))
                    .foregroundStyle(Arcana.Palette.muted)
                    .frame(width: 38, height: 44)
            }
        }
        .padding(.top, 6)
    }

    // MARK: Cards

    private var columns: [GridItem] {
        let count = min(spread.cards.count, 3)
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: max(count, 1))
    }

    private var highlightIndex: Int? {
        spread.cards.count == 3 ? 1 : nil   // "Present" glows in a 3-card spread
    }

    private var cardsPanel: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(Array(spread.cards.enumerated()), id: \.element.id) { index, placed in
                if let card = Deck.card(id: placed.cardID) {
                    VStack(spacing: 7) {
                        Text(placed.position.uppercased())
                            .bodyFont(9.5, weight: .bold)
                            .kerning(1.4)
                            .foregroundStyle(index == highlightIndex
                                             ? Arcana.Palette.gold : Arcana.Palette.muted)
                        Group {
                            if index == highlightIndex {
                                CardArtView(card: card, orientation: placed.orientation)
                                    .goldGlow()
                            } else {
                                CardArtView(card: card, orientation: placed.orientation)
                            }
                        }
                        .aspectRatio(0.6, contentMode: .fit)

                        Text(placed.orientation == .reversed ? "\(card.name) (R)" : card.name)
                            .bodyFont(12.5, weight: .bold)
                            .foregroundStyle(Arcana.Palette.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    // Stagger-fade, 60ms apart, per the wireframe note.
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.45).delay(Double(index) * 0.06),
                               value: appeared)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glass()
    }

    private var notesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES")
                .bodyFont(10, weight: .bold)
                .kerning(1.4)
                .foregroundStyle(Arcana.Palette.muted)
            Text(spread.note)
                .bodyFont(13.5)
                .foregroundStyle(Arcana.Palette.text)
                .lineSpacing(5)
        }
        .padding(.horizontal, 17).padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass()
    }
}
