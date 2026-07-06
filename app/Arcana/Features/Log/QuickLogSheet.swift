import SwiftUI

/// Quick-log bottom sheet — wireframe 2b. The default, 10-second logging path:
/// search → orientation → note → save. Springs up from ⊕ or the empty today tile.
/// If today's card is already logged it opens pre-filled and updates in place.
struct QuickLogSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss

    @State private var cardID: String?
    @State private var orientation: Orientation = .upright
    @State private var note = ""
    @State private var editingPullID: UUID?

    private var card: TarotCard? { cardID.flatMap(Deck.card(id:)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            Text(editingPullID == nil ? "Log today's card" : "Edit today's card")
                .displayFont(24)
                .foregroundStyle(Arcana.Palette.text)

            CardPicker(selectedCardID: $cardID)

            if cardID != nil {
                Button {
                    withAnimation(.snappy) { cardID = nil }
                } label: {
                    Text("change card")
                        .bodyFont(12.5)
                        .foregroundStyle(Arcana.Palette.faint)
                }
                .frame(maxWidth: .infinity)

                OrientationSegment(orientation: $orientation)

                NotesEditor(text: $note, prompt: "What does it stir up?…")

                GoldButton(title: "Save to ledger ✦") { save() }
            }

            // Optional side doors — manual log stays the primary path.
            HStack {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        router.showDraw = true
                    }
                } label: {
                    Label("Draw from the deck", systemImage: "sparkles")
                        .bodyFont(12.5, weight: .semibold)
                        .foregroundStyle(Arcana.Palette.purpleSoft)
                }
                Spacer()
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        router.showSpreadBuilder = true
                    }
                } label: {
                    Label("Start a spread", systemImage: "rectangle.grid.3x1")
                        .bodyFont(12.5, weight: .semibold)
                        .foregroundStyle(Arcana.Palette.blueSoft)
                }
            }
            .padding(.top, 2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .background(Color(hex: 0x13101E).opacity(0.98))
        .presentationDetents(cardID == nil ? [.medium, .large] : [.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(30)
        .onAppear(perform: prefill)
    }

    private func prefill() {
        if let (id, o) = router.consumePrefill() {
            // Arriving from the draw flow — "Journal it" drops in pre-filled.
            cardID = id
            orientation = o
        } else if let today = store.todayPull {
            editingPullID = today.id
            cardID = today.cardID
            orientation = today.orientation
            note = today.note
        }
    }

    private func save() {
        guard let cardID else { return }
        Task {
            var pull = CardPull(cardID: cardID, orientation: orientation, note: note, date: Date())
            if let editingPullID { pull.id = editingPullID }
            await store.save(pull)   // soft haptic on save lives in the store
            dismiss()
        }
    }
}
