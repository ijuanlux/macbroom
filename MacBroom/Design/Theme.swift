import SwiftUI

enum Theme {
    static let stripeGreen  = Color(red: 0.40, green: 0.74, blue: 0.36)
    static let stripeYellow = Color(red: 0.98, green: 0.78, blue: 0.20)
    static let stripeOrange = Color(red: 0.96, green: 0.55, blue: 0.18)
    static let stripeRed    = Color(red: 0.91, green: 0.30, blue: 0.27)
    static let stripePurple = Color(red: 0.61, green: 0.34, blue: 0.71)
    static let stripeBlue   = Color(red: 0.18, green: 0.56, blue: 0.86)

    /// Bright Matrix green for hacker mode accents.
    static let hackerGreen  = Color(red: 0.20, green: 0.95, blue: 0.35)
    /// Dim green for hacker mode secondary text.
    static let hackerDim    = Color(red: 0.10, green: 0.55, blue: 0.20)

    static let rainbow: [Color] = [stripeGreen, stripeYellow, stripeOrange, stripeRed, stripePurple, stripeBlue]

    /// Hacker mode "rainbow" — actually a gradient of green tones for cohesion.
    static let hackerStripes: [Color] = [
        Color(red: 0.10, green: 0.60, blue: 0.20),
        Color(red: 0.20, green: 0.95, blue: 0.35),
        Color(red: 0.50, green: 1.00, blue: 0.55),
        Color(red: 0.20, green: 0.95, blue: 0.35),
        Color(red: 0.10, green: 0.60, blue: 0.20),
    ]

    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let surface        = Color(nsColor: .windowBackgroundColor)
}

extension LinearGradient {
    static let rainbow = LinearGradient(
        colors: Theme.rainbow,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let hackerStripes = LinearGradient(
        colors: Theme.hackerStripes,
        startPoint: .leading,
        endPoint: .trailing
    )
}
