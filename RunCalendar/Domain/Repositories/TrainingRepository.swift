import Foundation

/// Contrato de persistencia de entrenamientos. Implementado con Firestore en la capa Data.
protocol TrainingRepository: Sendable {
    /// Stream de sesiones del usuario, ordenadas por fecha. Reacciona a cambios remotos.
    func trainingsStream(userID: String) -> AsyncStream<[TrainingSession]>

    func add(_ session: TrainingSession, userID: String) async throws
    func update(_ session: TrainingSession, userID: String) async throws
    func delete(sessionID: String, userID: String) async throws
}
