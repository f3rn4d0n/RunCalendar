import SwiftUI
import UIKit

/// Paleta neón adaptable de la app. Cada color tiene una variante para modo claro
/// (más profunda/saturada, legible sobre blanco) y otra para modo oscuro (con brillo).
enum Neon {
    static let accent = adaptive(light: 0x0A6CF0, dark: 0x1FB2FF) // azul neón
    static let green  = adaptive(light: 0x4E9A2F, dark: 0x9EE64B)
    static let teal   = adaptive(light: 0x009E86, dark: 0x2BE7C7)
    static let orange = adaptive(light: 0xE9720B, dark: 0xFF9A3D)
    static let purple = adaptive(light: 0x8A2BE2, dark: 0xC15CFF)
    static let gold   = adaptive(light: 0xB8860B, dark: 0xFFC53D)

    /// Degradado neón multicolor, inspirado en el app icon (magenta → naranja → amarillo → cian).
    static let logoGradient = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.16, blue: 0.60), // magenta neón
            Color(red: 1.00, green: 0.48, blue: 0.10), // naranja
            Color(red: 1.00, green: 0.85, blue: 0.10), // amarillo
            Color(red: 0.10, green: 0.80, blue: 1.00)  // cian
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
