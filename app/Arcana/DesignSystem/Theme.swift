import SwiftUI

/// Cosmic-glass palette — the `1l` visual direction the user selected.
/// Values are lifted directly from the wireframe CSS so the build matches the mockups.
enum Arcana {

    enum Palette {
        // Backgrounds
        static let inkTop      = Color(hex: 0x0D0B13)
        static let inkBottom   = Color(hex: 0x131020)
        static let panelTop    = Color(hex: 0x12101C)
        static let panelBottom = Color(hex: 0x171327)

        // Text
        static let text   = Color(hex: 0xF2EEF7)
        static let muted  = Color(hex: 0xA698B3)
        static let faint  = Color(hex: 0x8D81A3)

        // Accents
        static let gold       = Color(hex: 0xF6CE55)
        static let goldDeep   = Color(hex: 0xE0B23E)
        static let purple     = Color(hex: 0xB385E0)
        static let purpleDeep = Color(hex: 0x9367CF)
        static let purpleSoft = Color(hex: 0xC8A6EE)
        static let blue       = Color(hex: 0x66AACC)
        static let blueSoft   = Color(hex: 0x9EC8E2)

        // Glass strokes / fills
        static let glassFill   = Color(hex: 0x181622).opacity(0.62)
        static let glassStroke = Color(hex: 0x422E6B).opacity(0.55)
        static let hairline    = Color(hex: 0x422E6B).opacity(0.50)
        static let fieldFill   = Color(hex: 0x252537).opacity(0.70)
        static let fieldStroke = Color(hex: 0x392D53)
        static let starGold    = Color(hex: 0xFFF2CC)
    }

    /// The app-wide background: two nebula radials over a vertical ink gradient,
    /// matching `.hf` in the wireframe.
    struct CosmosBackground: View {
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Palette.inkTop, Palette.inkBottom],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color(hex: 0x583A8A).opacity(0.38), .clear],
                    center: UnitPoint(x: 0.2, y: 0.12), startRadius: 0, endRadius: 320
                )
                RadialGradient(
                    colors: [Color(hex: 0x1E4A66).opacity(0.32), .clear],
                    center: UnitPoint(x: 0.82, y: 0.88), startRadius: 0, endRadius: 320
                )
            }
            .ignoresSafeArea()
        }
    }

    /// Gradient used for the brand wordmark and section highlights (`.gtx`).
    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0xB385E0), Color(hex: 0xB561D1), Color(hex: 0x66AACC)],
        startPoint: .leading, endPoint: .trailing
    )

    static let goldGradient = LinearGradient(
        colors: [Palette.gold, Palette.goldDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let purpleGradient = LinearGradient(
        colors: [Palette.purple, Palette.purpleDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
