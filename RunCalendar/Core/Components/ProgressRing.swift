import SwiftUI

/// Anillo de progreso del UI Kit: pista tenue + arco de color, con contenido al centro.
/// Reutilizable para recuperación, ACWR, readiness, etc.
struct ProgressRing<Center: View>: View {
    /// Progreso 0–1.
    let progress: Double
    var color: Color = Neon.accent
    var lineWidth: CGFloat = 8
    var size: CGFloat = 74
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center()
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
    }
}

extension ProgressRing where Center == EmptyView {
    init(progress: Double, color: Color = Neon.accent, lineWidth: CGFloat = 8, size: CGFloat = 74) {
        self.init(progress: progress, color: color, lineWidth: lineWidth, size: size) { EmptyView() }
    }
}
