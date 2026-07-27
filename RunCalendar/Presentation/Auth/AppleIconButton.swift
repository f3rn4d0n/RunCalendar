import SwiftUI

/// Botón solo-ícono de Sign in with Apple, usando el logo oficial (`apple.logo`).
/// Sigue los lineamientos: en oscuro va fondo blanco con logo negro (la app es dark-only).
struct AppleIconButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "apple.logo")
                .font(.system(size: 24))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Iniciar sesión con Apple")
    }
}
