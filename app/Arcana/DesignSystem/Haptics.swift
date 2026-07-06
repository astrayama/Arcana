import UIKit

/// System-wide haptics, per the wireframe note:
/// "soft on save · tick on card flip · rigid on streak milestones".
enum Haptics {
    /// Soft tap — used when saving an entry to the ledger.
    static func soft() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare(); g.impactOccurred(intensity: 0.7)
    }

    /// Crisp selection tick — used on the card-flip reveal and segment changes.
    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Rigid thud — used when a streak milestone is crossed.
    static func milestone() {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.prepare(); g.impactOccurred(intensity: 1.0)
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
