import Foundation

/// Contrato del review dominical (lo subjetivo: energía y hambre).
/// Implementado con Firestore en la capa Data.
protocol BodyLogRepository: Sendable {
    func save(_ log: BodyLog, userID: String) async throws

    /// Reviews de los últimos `days` días, del más reciente al más viejo.
    func fetchRecent(days: Int, userID: String) async throws -> [BodyLog]
}
