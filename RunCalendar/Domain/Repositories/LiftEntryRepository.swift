import Foundation

/// Contrato de persistencia de resultados de levantamiento sueltos (sin WOD). Implementado con
/// Firestore en la capa Data.
protocol LiftEntryRepository: Sendable {
    /// Stream de resultados del usuario. Reacciona a cambios remotos.
    func entriesStream(userID: String) -> AsyncStream<[LiftEntry]>

    func add(_ entry: LiftEntry, userID: String) async throws
    func update(_ entry: LiftEntry, userID: String) async throws
    func delete(entryID: String, userID: String) async throws
}
