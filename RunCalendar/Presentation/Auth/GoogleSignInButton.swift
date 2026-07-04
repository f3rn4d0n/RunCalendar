import SwiftUI

/// Botón de "Continuar con Google" con el estilo de marca (rojo, logo "G" y texto blancos).
struct GoogleSignInButton: View {
    let action: () -> Void

    private let googleRed = Color(red: 0.85, green: 0.27, blue: 0.22) // #DB4437

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("G")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Text("Continuar con Google")
                    .font(.mHeadline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(googleRed, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continuar con Google")
    }
}
