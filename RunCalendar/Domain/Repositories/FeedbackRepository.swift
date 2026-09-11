import Foundation

/// Envía comentarios del usuario a un almacén que el equipo pueda leer.
protocol FeedbackRepository: Sendable {
    /// Guarda un comentario nuevo (documento con id automático).
    func submit(_ feedback: Feedback, userID: String) async throws
}
