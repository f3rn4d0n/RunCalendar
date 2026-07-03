import Foundation

/// Observa el perfil del usuario en tiempo real.
struct ObserveProfileUseCase: Sendable {
    private let repository: ProfileRepository
    init(repository: ProfileRepository) { self.repository = repository }

    func callAsFunction(userID: String) -> AsyncStream<UserProfile?> {
        repository.profileStream(userID: userID)
    }
}

/// Guarda (crea o actualiza) el perfil del usuario.
struct SaveProfileUseCase: Sendable {
    private let repository: ProfileRepository
    init(repository: ProfileRepository) { self.repository = repository }

    func callAsFunction(_ profile: UserProfile, userID: String) async throws {
        try await repository.save(profile, userID: userID)
    }
}
