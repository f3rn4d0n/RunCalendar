import SwiftUI

/// Brillo que barre de izquierda a derecha para skeletons de carga.
/// Úsalo sobre placeholders (`.redacted(reason: .placeholder)` o formas atenuadas):
/// `MiPlaceholder().shimmering()`. El brillo se limita a la silueta del contenido.
private struct ShimmerModifier: ViewModifier {
    @State private var animating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(colors: [.clear, Color.white.opacity(0.45), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: w)
                        .offset(x: animating ? w : -w)
                }
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            )
            .mask(content) // el brillo solo aparece donde el contenido es opaco
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    animating = true
                }
            }
    }
}

extension View {
    /// Anima un brillo de carga sobre este contenido (skeleton).
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

// Valida la animación en aislamiento (el canvas la deja en loop, sin depender
// de cuánto tarde la carga real). Abre el canvas de Xcode en este archivo.
#Preview("Shimmer") {
    HStack(spacing: 14) {
        Circle().fill(Color.primary.opacity(0.08)).frame(width: 58, height: 58)
        VStack(alignment: .leading, spacing: 4) {
            Text("Recuperado").font(.headline)
            Text("para estar listo").font(.caption)
        }
        .redacted(reason: .placeholder)
        Spacer()
    }
    .shimmering()
    .padding()
}
