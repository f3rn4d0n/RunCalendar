import SwiftUI

/// Botón solo-ícono de Sign in with Apple, usando el logo oficial (`apple.logo`).
/// Sigue los lineamientos: fondo negro/logo blanco en claro, e invertido en oscuro.
struct AppleIconButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: "apple.logo")
                .font(.system(size: 24))
                .foregroundStyle(colorScheme == .dark ? .black : .white)
                .frame(width: 56, height: 56)
                .background(
                    colorScheme == .dark ? Color.white : Color.black,
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Iniciar sesión con Apple")
    }
}
