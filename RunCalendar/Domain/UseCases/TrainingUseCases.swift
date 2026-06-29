import Foundation

/// Observa las sesiones de entrenamiento del usuario en tiempo real.
struct ObserveTrainingsUseCase: Sendable {
    private let repository: TrainingRepository
    init(repository: TrainingRepository) { self.repository = repository }

    func callAsFunction(userID: String) -> AsyncStream<[TrainingSession]> {
        repository.trainingsStream(userID: userID)
    }
}

/// Agrega una sesión de entrenamiento.
struct AddTrainingUseCase: Sendable {
    private let repository: TrainingRepository
    init(repository: TrainingRepository) { self.repository = repository }

    func callAsFunction(_ session: TrainingSession, userID: String) async throws {
        try validate(session)
        try await repository.add(session, userID: userID)
    }

    private func validate(_ session: TrainingSession) throws {
        guard !session.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AppError.invalidInput("El título del entrenamiento es obligatorio.")
        }
    }
}

/// Actualiza una sesión de entrenamiento.
struct UpdateTrainingUseCase: Sendable {
    private let repository: TrainingRepository
    init(repository: TrainingRepository) { self.repository = repository }

    func callAsFunction(_ session: TrainingSession, userID: String) async throws {
        guard !session.title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AppError.invalidInput("El título del entrenamiento es obligatorio.")
        }
        try await repository.update(session, userID: userID)
    }
}

/// Elimina una sesión de entrenamiento.
struct DeleteTrainingUseCase: Sendable {
    private let repository: TrainingRepository
    init(repository: TrainingRepository) { self.repository = repository }

    func callAsFunction(sessionID: String, userID: String) async throws {
        try await repository.delete(sessionID: sessionID, userID: userID)
    }
}
