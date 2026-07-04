import SwiftUI

/// Botón solo-ícono de Google (la "G" blanca sobre rojo de marca).
struct GoogleSignInButton: View {
    let action: () -> Void

    private let googleRed = Color(red: 0.85, green: 0.27, blue: 0.22) // #DB4437

    var body: some View {
        Button(action: action) {
            Text("G")
                .font(.system(size: 26, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(googleRed, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continuar con Google")
    }
}
