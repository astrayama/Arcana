import SwiftUI

/// A single logged card, opened from Today or a journal row.
/// Shows the art large, editable orientation & note, and the collapsible insight.
struct CardDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State var pull: CardPull
    @State private var confirmDelete = false

    private var card: TarotCard? { Deck.card(id: pull.cardID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let card {
                    CardArtView(card: card, orientation: pull.orientation)
                        .frame(width: 180, height: 300)
                        .floating(amplitude: 4)
                        .goldGlow()
                        .padding(.top, 8)

                    Text(card.name)
                        .displayFont(30)
                        .foregroundStyle(Arcana.Palette.text)
                    Text("\(card.subtitle) · \(pull.date.formatted(.dateTime.month(.wide).day()))")
                        .bodyFont(13)
                        .foregroundStyle(Arcana.Palette.muted)

                    OrientationSegment(orientation: orientationBinding)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES")
                            .bodyFont(10, weight: .bold)
                            .kerning(1.4)
                            .foregroundStyle(Arcana.Palette.muted)
                        NotesEditor(text: noteBinding, prompt: "What did it stir up?…")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glass()

                    InsightDisclosure(title: "AI insight") {
                        await InsightService.insight(
                            for: card, orientation: pull.orientation, note: pull.note
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background {
            Arcana.CosmosBackground()
            StarfieldView()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Arcana.Palette.muted)
                }
            }
        }
        .confirmationDialog("Delete this entry from your ledger?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await store.delete(.pull(pull))
                    dismiss()
                }
            }
        }
        .onDisappear { flushNoteIfNeeded() }
    }

    // Orientation saves on tap; the note saves quietly when the screen closes.

    private var orientationBinding: Binding<Orientation> {
        Binding(get: { pull.orientation }) { newValue in
            pull.orientation = newValue
            Task { await store.save(pull, haptic: false) }
        }
    }

    private var noteBinding: Binding<String> {
        Binding(get: { pull.note }) { newValue in
            pull.note = newValue
            noteDirty = true
        }
    }

    @State private var noteDirty = false
}

extension CardDetailView {
    /// Persist pending note edits when leaving the screen.
    func flushNoteIfNeeded() {
        guard noteDirty else { return }
        let snapshot = pull
        Task { await store.save(snapshot, haptic: false) }
    }
}
