import Foundation

/// Contrato de persistencia de objetivos. Implementado con Firestore en la capa Data.
protocol GoalRepository: Sendable {
    /// Stream de metas del usuario. Reacciona a cambios remotos.
    func goalsStream(userID: String) -> AsyncStream<[Goal]>

    func add(_ goal: Goal, userID: String) async throws
    func update(_ goal: Goal, userID: String) async throws
    func delete(goalID: String, userID: String) async throws
}
