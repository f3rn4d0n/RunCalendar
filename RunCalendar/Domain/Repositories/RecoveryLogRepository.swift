import Foundation

/// Guarda y lee los check-ins diarios de recuperación (para calibrar el modelo).
protocol RecoveryLogRepository: Sendable {
    /// Guarda (o reemplaza) el check-in del día.
    func save(_ checkIn: RecoveryCheckIn, userID: String) async throws
    /// Check-ins de los últimos `days` días, de más antiguo a más reciente.
    func fetchRecent(days: Int, userID: String) async throws -> [RecoveryCheckIn]
}
