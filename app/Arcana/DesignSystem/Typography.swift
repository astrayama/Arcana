import SwiftUI
import UIKit

/// Typography matching the wireframe: Playfair Display (serif) for display text,
/// Nunito for body/UI.
///
/// If the bundled `.ttf` files are present they are used verbatim; if not, we fall
/// back to the system serif / rounded designs so the app still renders correctly.
/// Drop the font files into `Resources/Fonts/` (already declared in Info.plist) to
/// get pixel-exact type.
enum AppFont {

    // MARK: Playfair Display (display / headings)

    static func display(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "PlayfairDisplay-SemiBold"
        case .semibold:             name = "PlayfairDisplay-SemiBold"
        case .regular, .light:      name = "PlayfairDisplay-Regular"
        default:                    name = "PlayfairDisplay-Medium"
        }
        if isAvailable(name) { return .custom(name, size: size) }
        return .system(size: size, weight: weight, design: .serif)
    }

    // MARK: Nunito (body / UI)

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black, .heavy: name = "Nunito-ExtraBold"
        case .bold:          name = "Nunito-Bold"
        case .semibold:      name = "Nunito-SemiBold"
        default:             name = "Nunito-Regular"
        }
        if isAvailable(name) { return .custom(name, size: size) }
        return .system(size: size, weight: weight, design: .rounded)
    }

    private static var checked: [String: Bool] = [:]
    private static func isAvailable(_ name: String) -> Bool {
        if let cached = checked[name] { return cached }
        let ok = UIFont(name: name, size: 12) != nil
        checked[name] = ok
        return ok
    }
}

extension View {
    /// Playfair display text.
    func displayFont(_ size: CGFloat, weight: Font.Weight = .medium) -> some View {
        font(AppFont.display(size, weight: weight))
    }
    /// Nunito UI text.
    func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(AppFont.body(size, weight: weight))
    }
}
