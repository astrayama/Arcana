import SwiftUI

/// Build a reading: pick a template (or custom positions), place a card in each
/// position, add a title & notes, save to the ledger.
struct SpreadBuilderFlow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss

    @State private var template: SpreadTemplate = .threeCard
    @State private var isCustom = false
    @State private var customPositions: [String] = ["Card 1", "Card 2", "Card 3"]
    @State private var title = ""
    @State private var note = ""
    /// position index → (cardID, orientation)
    @State private var placements: [Int: (String, Orientation)] = [:]
    @State private var pickingIndex: Int?

    private var positions: [String] { isCustom ? customPositions : template.positions }
    private var isComplete: Bool { positions.indices.allSatisfy { placements[$0] != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    templateChooser

                    if isCustom { customEditor }

                    VStack(spacing: 10) {
                        ForEach(positions.indices, id: \.self) { index in
                            PositionSlot(
                                position: positions[index],
                                placement: placements[index],
                                isPicking: pickingIndex == index,
                                onTap: {
                                    withAnimation(.snappy) {
                                        pickingIndex = pickingIndex == index ? nil : index
                                    }
                                },
                                onPick: { cardID in
                                    Haptics.tick()
                                    withAnimation(.snappy) {
                                        placements[index] = (cardID, .upright)
                                        pickingIndex = nil
                                    }
                                },
                                onFlip: {
                                    guard let (id, o) = placements[index] else { return }
                                    Haptics.tick()
                                    placements[index] = (id, o == .upright ? .reversed : .upright)
                                },
                                onClear: {
                                    withAnimation(.snappy) { placements[index] = nil }
                                }
                            )
                        }
                    }

                    TextField("Title — e.g. Career check-in", text: $title)
                        .bodyFont(14)
                        .foregroundStyle(Arcana.Palette.text)
                        .glassField()

                    NotesEditor(text: $note, prompt: "What do the cards say together?…")

                    GoldButton(title: "Save to ledger ✦") { save() }
                        .opacity(isComplete ? 1 : 0.45)
                        .disabled(!isComplete)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(Color(hex: 0x13101E).opacity(0.98).ignoresSafeArea())
            .navigationTitle("New spread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Arcana.Palette.muted)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(30)
        .onAppear {
            if let chosen = router.spreadBuilderTemplate {
                template = chosen
                isCustom = false
            } else {
                isCustom = true
            }
            router.spreadBuilderTemplate = .threeCard   // reset default
        }
    }

    // MARK: Template chooser

    private var templateChooser: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(SpreadTemplate.builtIn) { t in
                    Chip(label: t.name, isOn: !isCustom && template.id == t.id) {
                        withAnimation(.snappy) {
                            template = t
                            isCustom = false
                            placements = [:]
                            pickingIndex = nil
                        }
                    }
                }
                Chip(label: "Custom", isOn: isCustom) {
                    withAnimation(.snappy) {
                        isCustom = true
                        placements = [:]
                        pickingIndex = nil
                    }
                }
            }
        }
    }

    private var customEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("POSITIONS")
                    .bodyFont(10, weight: .bold)
                    .kerning(1.4)
                    .foregroundStyle(Arcana.Palette.muted)
                Spacer()
                Button {
                    guard customPositions.count > 1 else { return }
                    customPositions.removeLast()
                    placements[customPositions.count] = nil
                } label: {
                    Image(systemName: "minus.circle").foregroundStyle(Arcana.Palette.muted)
                }
                Button {
                    guard customPositions.count < 10 else { return }
                    customPositions.append("Card \(customPositions.count + 1)")
                } label: {
                    Image(systemName: "plus.circle").foregroundStyle(Arcana.Palette.purpleSoft)
                }
            }
            ForEach(customPositions.indices, id: \.self) { i in
                TextField("Position name", text: $customPositions[i])
                    .bodyFont(13)
                    .foregroundStyle(Arcana.Palette.text)
                    .glassField()
            }
        }
    }

    private func save() {
        let cards = positions.indices.compactMap { index -> SpreadCard? in
            guard let (cardID, orientation) = placements[index] else { return nil }
            return SpreadCard(position: positions[index], cardID: cardID, orientation: orientation)
        }
        let spread = Spread(
            title: title.isEmpty ? (isCustom ? "Custom spread" : template.name) : title,
            templateID: isCustom ? "custom" : template.id,
            templateName: isCustom ? positions.joined(separator: " · ") : template.name,
            cards: cards,
            note: note,
            date: Date()
        )
        Task {
            await store.save(spread)
            dismiss()
        }
    }
}

// MARK: - One position slot

private struct PositionSlot: View {
    let position: String
    let placement: (String, Orientation)?
    let isPicking: Bool
    var onTap: () -> Void
    var onPick: (String) -> Void
    var onFlip: () -> Void
    var onClear: () -> Void

    @State private var searchID: String?

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    if let (cardID, orientation) = placement, let card = Deck.card(id: cardID) {
                        CardArtView(card: card, orientation: orientation)
                            .frame(width: 34, height: 57)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(position.uppercased())
                                .bodyFont(9.5, weight: .bold)
                                .kerning(1.2)
                                .foregroundStyle(Arcana.Palette.gold)
                            Text("\(card.name) \(orientation.arrow)")
                                .bodyFont(14, weight: .bold)
                                .foregroundStyle(Arcana.Palette.text)
                        }
                        Spacer()
                        Button(action: onFlip) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 13))
                                .foregroundStyle(Arcana.Palette.muted)
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Arcana.Palette.faint)
                                .frame(width: 30, height: 34)
                        }
                        .buttonStyle(.plain)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Arcana.Palette.gold.opacity(0.4),
                                          style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .frame(width: 34, height: 57)
                            .overlay(Text("+").foregroundStyle(Arcana.Palette.gold.opacity(0.7)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(position.uppercased())
                                .bodyFont(9.5, weight: .bold)
                                .kerning(1.2)
                                .foregroundStyle(Arcana.Palette.muted)
                            Text("Choose a card")
                                .bodyFont(14, weight: .semibold)
                                .foregroundStyle(Arcana.Palette.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Arcana.Palette.faint)
                            .rotationEffect(.degrees(isPicking ? 180 : 0))
                    }
                }
                .padding(.horizontal, 13).padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isPicking {
                CardPicker(selectedCardID: Binding(
                    get: { searchID },
                    set: { newValue in
                        if let newValue { onPick(newValue) }
                        searchID = nil
                    }
                ))
                .padding(.horizontal, 13)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glass(cornerRadius: 14)
    }
}
