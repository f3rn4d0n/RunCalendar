import SwiftUI

/// Estilo de botón primario con degradado neón y glow.
struct NeonButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Neon.buttonGradient, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: Neon.accent.opacity(0.6), radius: configuration.isPressed ? 4 : 12)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
