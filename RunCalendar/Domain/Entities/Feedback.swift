import Foundation

/// Un comentario que el usuario manda al equipo desde Perfil.
/// Texto libre + una valoración 1–5; se guarda en Firestore (`feedback/{autoID}`),
/// no en el árbol del usuario, para poder leerlo todo junto.
struct Feedback: Sendable, Equatable {
    /// Lo que escribió el usuario. Nunca vacío (lo garantiza `SubmitFeedbackUseCase`).
    let text: String
    /// Valoración de la app, 1 (mal) a 5 (excelente).
    let rating: Int
    let createdAt: Date
    /// `CFBundleShortVersionString` al momento de enviar: sitúa el comentario en una versión.
    let appVersion: String
    /// p. ej. "iOS 18.0" — para reproducir problemas dependientes de versión.
    let systemVersion: String
}
