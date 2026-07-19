import SwiftUI
import UIKit

/// Paleta neón adaptable de la app. Cada color tiene una variante para modo claro
/// (más profunda/saturada, legible sobre blanco) y otra para modo oscuro (con brillo).
enum Neon {
    // Valores del RunCalendar UI Kit: dark = identidad insignia; light = tono armonizado, legible.
    static let accent = adaptive(light: 0x2E6FE6, dark: 0x3D8BFF) // azul periwinkle
    static let green  = adaptive(light: 0x0E9E6A, dark: 0x34D399) // esmeralda
    static let teal   = adaptive(light: 0x0FA9A2, dark: 0x2DD4CE)
    static let orange = adaptive(light: 0xD97A22, dark: 0xFF9F45)
    static let purple = adaptive(light: 0x7C5CE0, dark: 0xA78BFA)
    static let pink   = adaptive(light: 0xD14E86, dark: 0xFF6FA8)
    static let gold   = adaptive(light: 0xB7841E, dark: 0xFFD166)

    /// Degradado para botones primarios (azul → púrpura, del Kit).
    static let buttonGradient = LinearGradient(
        colors: [
            Color(red: 0.239, green: 0.545, blue: 1.000), // #3D8BFF
            Color(red: 0.655, green: 0.545, blue: 0.980)  // #A78BFA
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Degradado neón multicolor de branding (rosa → naranja → oro → verde → azul, del Kit).
    static let logoGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 1.000, green: 0.435, blue: 0.659), location: 0.00), // #FF6FA8
            .init(color: Color(red: 1.000, green: 0.624, blue: 0.271), location: 0.35), // #FF9F45
            .init(color: Color(red: 1.000, green: 0.820, blue: 0.400), location: 0.55), // #FFD166
            .init(color: Color(red: 0.204, green: 0.827, blue: 0.600), location: 0.75), // #34D399
            .init(color: Color(red: 0.239, green: 0.545, blue: 1.000), location: 1.00)  // #3D8BFF
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
