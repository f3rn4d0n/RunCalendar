import SwiftUI
import UIKit

/// Paleta neón de la app. **Dark-only**: la app fija `UIUserInterfaceStyle: Dark`
/// (ver `project.yml`), así que estos son los valores del RunCalendar UI Kit tal cual,
/// sin variante clara. Cambia aquí y se propaga a toda la app.
enum Neon {
    static let accent = color(0x3D8BFF) // azul periwinkle
    static let green  = color(0x34D399) // esmeralda
    static let teal   = color(0x2DD4CE)
    static let orange = color(0xFF9F45)
    static let purple = color(0xA78BFA)
    static let pink   = color(0xFF6FA8)
    static let gold   = color(0xFFD166)

    // Superficies del Kit.
    static let background      = color(0x0A0C10) // fondo de pantalla
    static let surface         = color(0x14171D) // card
    static let surfaceElevated = color(0x1A1E26) // card sobre card / casillas

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

    private static func color(_ rgb: UInt) -> Color {
        Color(uiColor: UIColor(rgb: rgb))
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
