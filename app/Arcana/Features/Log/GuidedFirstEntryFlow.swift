import SwiftUI

/// First-ever entry — wireframe 2g. A guided 3-step walk (pick → orientation +
/// meaning → reflection) shown exactly once; every later log uses `QuickLogSheet`.
struct GuidedFirstEntryFlow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var cardID: String?
    @State private var orientation: Orientation = .upright
    @State private var note = ""
    @State private var skippedToQuickLog = false

    private var card: TarotCard? { cardID.flatMap(Deck.card(id:)) }

    var body: some View {
        ZStack {
            Arcana.CosmosBackground()
            StarfieldView(opacity: 0.3)

            if skippedToQuickLog {
                QuickLogSheet()
            } else {
                VStack(spacing: 16) {
                    // Progress segments
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? Arcana.Palette.purple : Color(hex: 0x252537))
                                .frame(height: 4)
                        }
                    }
                    .padding(.top, 18)

                    Text("YOUR FIRST ENTRY · \(step + 1) OF 3")
                        .bodyFont(10.5, weight: .bold)
                        .kerning(1.6)
                        .foregroundStyle(Arcana.Palette.muted)

                    switch step {
                    case 0: pickStep
                    case 1: orientationStep
                    default: reflectStep
                    }

                    Spacer(minLength: 0)

                    footer
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 26)
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Step 1 — pick the card

    private var pickStep: some View {
        VStack(spacing: 14) {
            Text("Which card found you today?")
                .displayFont(25)
                .foregroundStyle(Arcana.Palette.text)
                .multilineTextAlignment(.center)
            CardPicker(selectedCardID: $cardID)
            if cardID != nil {
                Button {
                    withAnimation(.snappy) { cardID = nil }
                } label: {
                    Text("change card")
                        .bodyFont(12.5)
                        .foregroundStyle(Arcana.Palette.faint)
                }
            }
        }
    }

    // MARK: Step 2 — orientation + meaning

    private var orientationStep: some View {
        VStack(spacing: 14) {
            if let card {
                CardArtView(card: card, orientation: orientation)
                    .frame(width: 150, height: 250)
                    .goldGlow()
                Text(card.name)
                    .displayFont(27)
                    .foregroundStyle(Arcana.Palette.text)
                OrientationSegment(orientation: $orientation)
                InsightDisclosure(
                    title: "\(orientation.label), \(card.name) speaks to…"
                ) {
                    await InsightService.insight(for: card, orientation: orientation, note: note)
                }
            }
        }
    }

    // MARK: Step 3 — reflection

    private var reflectStep: some View {
        VStack(spacing: 14) {
            if let card {
                HStack(spacing: 12) {
                    CardArtView(card: card, orientation: orientation)
                        .frame(width: 40, height: 67)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(card.name) \(orientation.arrow)")
                            .bodyFont(15, weight: .bold)
                            .foregroundStyle(Arcana.Palette.text)
                        Text(card.subtitle)
                            .bodyFont(12)
                            .foregroundStyle(Arcana.Palette.muted)
                    }
                    Spacer()
                }
            }
            Text("Add a reflection")
                .displayFont(25)
                .foregroundStyle(Arcana.Palette.text)
            NotesEditor(text: $note, prompt: "What does it stir up?…")
            Text("prompt: where does this show up in your day?")
                .bodyFont(11.5)
                .foregroundStyle(Arcana.Palette.faint)
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            switch step {
            case 0:
                PurpleButton(title: "Next — orientation") {
                    guard cardID != nil else { return }
                    withAnimation(.snappy) { step = 1 }
                }
                .opacity(cardID == nil ? 0.45 : 1)
            case 1:
                PurpleButton(title: "Next — add a reflection") {
                    withAnimation(.snappy) { step = 2 }
                }
            default:
                GoldButton(title: "Save to ledger ✦") {
                    guard let cardID else { return }
                    Task {
                        await store.save(CardPull(
                            cardID: cardID, orientation: orientation,
                            note: note, date: Date()
                        ))
                        dismiss()
                    }
                }
            }

            Button {
                withAnimation(.snappy) { skippedToQuickLog = true }
            } label: {
                Text("skip — I know my way")
                    .bodyFont(12.5)
                    .foregroundStyle(Arcana.Palette.muted)
            }
        }
    }
}

/// Shared multiline notes editor with a placeholder.
struct NotesEditor: View {
    @Binding var text: String
    var prompt = "Notes…"
    var minHeight: CGFloat = 88

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .bodyFont(13.5)
                .foregroundStyle(Arcana.Palette.text)
                .frame(minHeight: minHeight)
            if text.isEmpty {
                Text(prompt)
                    .bodyFont(13.5)
                    .foregroundStyle(Arcana.Palette.muted)
                    .padding(.top, 8).padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Arcana.Palette.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Arcana.Palette.fieldStroke, lineWidth: 1)
        )
    }
}
