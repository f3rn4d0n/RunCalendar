import Foundation

/// Guarda el check-in diario de recuperación.
struct SaveRecoveryCheckInUseCase: Sendable {
    private let repository: RecoveryLogRepository
    init(repository: RecoveryLogRepository) { self.repository = repository }

    func callAsFunction(_ checkIn: RecoveryCheckIn, userID: String) async throws {
        try await repository.save(checkIn, userID: userID)
    }
}

/// Trae los check-ins recientes (para saber si ya se registró hoy y, después, calibrar).
struct FetchRecoveryCheckInsUseCase: Sendable {
    private let repository: RecoveryLogRepository
    init(repository: RecoveryLogRepository) { self.repository = repository }

    func callAsFunction(days: Int = 60, userID: String) async throws -> [RecoveryCheckIn] {
        try await repository.fetchRecent(days: days, userID: userID)
    }
}
