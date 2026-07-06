import SwiftUI
import UIKit

/// Export — wireframe 2f. Pick a canvas (Post 1:1 · Story 9:16 · Journal PDF),
/// flip the content toggles, then render @3x and hand off to the iOS share sheet.
struct ExportView: View {
    @Environment(\.dismiss) private var dismiss

    let spread: Spread

    @State private var template: ExportTemplate = .story
    @State private var options = ExportOptions()
    @State private var cache: CardImageCache = [:]
    @State private var rendering = false
    @State private var shareItems: [Any]?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    templatePicker
                    togglesPanel
                    Spacer(minLength: 6)
                    GoldButton(title: rendering ? "Rendering…" : "Render & share ↥") {
                        render()
                    }
                    .disabled(rendering)
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
            .background {
                Arcana.CosmosBackground()
                StarfieldView(opacity: 0.3)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Arcana.Palette.muted)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(30)
        .task {
            cache = await prefetchCardImages(for: spread)
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let shareItems {
                ShareSheet(items: shareItems)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: Template picker — live scaled-down previews of the real canvases

    private var templatePicker: some View {
        HStack(alignment: .bottom, spacing: 14) {
            templateThumb(.post, width: 96, height: 96)
            templateThumb(.story, width: 118, height: 210)
            templateThumb(.pdf, width: 96, height: 132)
        }
        .frame(maxWidth: .infinity)
    }

    private func templateThumb(_ t: ExportTemplate, width: CGFloat, height: CGFloat) -> some View {
        let isOn = template == t
        let scale = min(width / t.size.width, height / t.size.height)
        return VStack(spacing: 7) {
            canvasView(for: t)
                .scaleEffect(scale)
                .frame(width: t.size.width * scale, height: t.size.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isOn ? Arcana.Palette.gold : Arcana.Palette.fieldStroke,
                                      lineWidth: isOn ? 2 : 1)
                )
                .shadow(color: isOn ? Arcana.Palette.gold.opacity(0.25) : .clear, radius: 11)

            Text(isOn ? "\(t.label) ✓" : t.label)
                .bodyFont(11.5, weight: .bold)
                .foregroundStyle(isOn ? Arcana.Palette.gold : Arcana.Palette.muted)
        }
        .onTapGesture {
            Haptics.tick()
            withAnimation(.snappy) { template = t }
        }
    }

    // MARK: Toggles — mirror the web app

    private var togglesPanel: some View {
        VStack(spacing: 0) {
            toggleRow("Include notes", isOn: $options.includeNotes)
            Divider().overlay(Arcana.Palette.hairline).padding(.horizontal, 16)
            toggleRow("Card images", isOn: $options.cardImages)
            Divider().overlay(Arcana.Palette.hairline).padding(.horizontal, 16)
            toggleRow("Show date", isOn: $options.showDate)
        }
        .glass()
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .bodyFont(14, weight: .semibold)
            .foregroundStyle(Arcana.Palette.text)
            .tint(Arcana.Palette.purple)
            .padding(.horizontal, 16).padding(.vertical, 13)
    }

    // MARK: Canvas + rendering

    @ViewBuilder
    private func canvasView(for t: ExportTemplate) -> some View {
        switch t {
        case .post: PostExportView(spread: spread, options: options, cache: cache)
        case .story: StoryExportView(spread: spread, options: options, cache: cache)
        case .pdf: JournalPageExportView(spread: spread, options: options, cache: cache)
        }
    }

    @MainActor
    private func render() {
        rendering = true
        defer { rendering = false }

        let renderer = ImageRenderer(content: canvasView(for: template))
        renderer.proposedSize = ProposedViewSize(template.size)

        switch template {
        case .post, .story:
            renderer.scale = 3   // @3x, per the wireframe note
            guard let image = renderer.uiImage else { return }
            Haptics.success()
            shareItems = [image]

        case .pdf:
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Arcana — \(sanitizedTitle).pdf")
            var box = CGRect(origin: .zero, size: template.size)
            guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            renderer.render { _, renderInContext in
                ctx.beginPDFPage(nil)
                renderInContext(ctx)
                ctx.endPDFPage()
                ctx.closePDF()
            }
            Haptics.success()
            shareItems = [url]
        }
    }

    private var sanitizedTitle: String {
        spread.title.replacingOccurrences(of: "/", with: "-")
    }
}

// MARK: - Native share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
