import SwiftUI

enum Theme {
    private static let accentPalette: [Color] = [
        Color(red: 0.0, green: 0.48, blue: 1.0),
        Color(red: 0.35, green: 0.34, blue: 0.84),
        Color(red: 0.69, green: 0.32, blue: 0.87),
        Color(red: 0.0, green: 0.78, blue: 0.75),
        Color(red: 1.0, green: 0.58, blue: 0.0),
        Color(red: 0.20, green: 0.78, blue: 0.35),
        Color(red: 1.0, green: 0.18, blue: 0.57),
        Color(red: 0.45, green: 0.45, blue: 0.50)
    ]

    private static func stablePaletteIndex(for string: String) -> Int {
        let h = string.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return abs(h) % accentPalette.count
    }

    static func providerAccent(for providerName: String) -> Color {
        accentPalette[stablePaletteIndex(for: providerName)]
    }

    /// Sidebar project dots: one distinct palette color per project (stable order), so peers don't collide like hash-based `providerAccent(for: uuidString)` can.
    static func projectAccent(for projectID: UUID, amongSortedProjectIDs sortedIDs: [UUID]) -> Color {
        guard let idx = sortedIDs.firstIndex(of: projectID) else {
            return accentPalette[stablePaletteIndex(for: projectID.uuidString)]
        }
        return accentPalette[idx % accentPalette.count]
    }

    static var systemAccent: Color { Color(nsColor: .controlAccentColor) }

    /// Unified title bar / window toolbar: matches main detail chrome (#FFFFFF) instead of `.regularMaterial`.
    static let windowToolbarBackground = Color(red: 1, green: 1, blue: 1)
}
