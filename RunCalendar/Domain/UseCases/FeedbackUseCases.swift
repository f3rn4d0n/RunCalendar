import Foundation

/// Envía un comentario del usuario. Rechaza el texto vacío para no llenar la
/// colección de documentos sin contenido.
struct SubmitFeedbackUseCase: Sendable {
    private let repository: FeedbackRepository
    init(repository: FeedbackRepository) { self.repository = repository }

    func callAsFunction(_ feedback: Feedback, userID: String) async throws {
        let text = feedback.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AppError.invalidInput("El comentario no puede estar vacío.")
        }
        let clean = Feedback(text: text, rating: feedback.rating, createdAt: feedback.createdAt,
                             appVersion: feedback.appVersion, systemVersion: feedback.systemVersion)
        try await repository.submit(clean, userID: userID)
    }
}
