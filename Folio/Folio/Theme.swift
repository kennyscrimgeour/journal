import SwiftUI

extension Color {
    /// Cream off-white, slightly warm. Per design.md §8.1.
    /// Flat colour for now — the paper texture comes later.
    static let folioPaper = Color(red: 0.98, green: 0.96, blue: 0.92)

    /// Deep warm near-black. Never pure #000. Per design.md §8.1.
    static let folioInk = Color(red: 0.18, green: 0.16, blue: 0.14)

    /// A slightly darker cream than folioPaper. Per design.md §8.1
    /// (revised 2026-05-17): same warm family as the active page,
    /// just dimmer — the journal feels like the same world in lower
    /// light rather than a different room.
    static let folioJournalBackground = Color(red: 0.95, green: 0.93, blue: 0.88)
}

/// Centralised haptic taps so we can tune intensities and styles in one place
/// rather than chasing UIImpactFeedbackGenerator usages across the codebase.
/// Per design.md §6.3, haptics are part of the product from day one.
enum FolioHaptic {
    /// Soft tap. Placing, committing, lifting, settling.
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// "Gentle, dignified pulse" for the page closing at midnight,
    /// per design.md §6.3.
    static func pageClose() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
