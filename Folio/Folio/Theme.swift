import SwiftUI

extension Color {
    /// Cream off-white, slightly warm. Per design.md §8.1.
    /// Flat colour for now — the paper texture comes later.
    static let folioPaper = Color(red: 0.98, green: 0.96, blue: 0.92)

    /// Deep warm near-black. Never pure #000. Per design.md §8.1.
    static let folioInk = Color(red: 0.18, green: 0.16, blue: 0.14)
}

/// Centralised haptic taps so we can tune intensities and styles in one place
/// rather than chasing UIImpactFeedbackGenerator usages across the codebase.
/// Per design.md §6.3, haptics are part of the product from day one.
enum FolioHaptic {
    /// Soft tap. Used when placing or committing a text element.
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
