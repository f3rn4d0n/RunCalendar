import UIKit

/// Retroalimentación háptica ligera para confirmar acciones del usuario.
/// En plataformas sin motor háptico (p. ej. Mac) las llamadas no tienen efecto.
@MainActor
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
