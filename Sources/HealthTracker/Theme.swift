import SwiftUI

extension Color {
    /// Creates a Color from a "#RRGGBB" / "RRGGBB" hex string. Falls back to accentColor.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        guard s.count == 6, let v = UInt64(s, radix: 16) else {
            self = .accentColor
            return
        }
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    static let cardCorner: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let gutter: CGFloat = 12

    /// Curated palette offered when creating a new habit.
    static let palette: [String] = [
        "#FF6B35", "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#30B0C7", "#5E5CE6", "#AF52DE", "#FF2D55", "#8E8E93"
    ]

    /// SF Symbols offered when creating a new habit.
    static let symbols: [String] = [
        "figure.run", "figure.walk", "figure.strengthtraining.traditional",
        "dumbbell", "figure.mind.and.body", "fork.knife", "drop.fill",
        "bed.double.fill", "brain.head.profile", "pills", "heart.fill",
        "bolt.fill", "book.fill", "leaf.fill", "moon.fill", "sun.max.fill",
        "checkmark.circle.fill", "flame.fill"
    ]
}
