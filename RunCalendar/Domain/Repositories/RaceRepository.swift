import Foundation

/// Contrato de persistencia de carreras. Implementado con Firestore en la capa Data.
protocol RaceRepository: Sendable {
    /// Stream de carreras del usuario, ordenadas por fecha. Reacciona a cambios remotos.
    func racesStream(userID: String) -> AsyncStream<[Race]>

    func add(_ race: Race, userID: String) async throws
    func update(_ race: Race, userID: String) async throws
    func delete(raceID: String, userID: String) async throws
}
