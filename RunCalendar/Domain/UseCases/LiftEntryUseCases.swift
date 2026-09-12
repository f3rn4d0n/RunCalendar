import Foundation

/// Observa los resultados sueltos de levantamiento del usuario en tiempo real.
struct ObserveLiftEntriesUseCase: Sendable {
    private let repository: LiftEntryRepository
    init(repository: LiftEntryRepository) { self.repository = repository }

    func callAsFunction(userID: String) -> AsyncStream<[LiftEntry]> {
        repository.entriesStream(userID: userID)
    }
}

/// Agrega un resultado nuevo.
struct AddLiftEntryUseCase: Sendable {
    private let repository: LiftEntryRepository
    init(repository: LiftEntryRepository) { self.repository = repository }

    func callAsFunction(_ entry: LiftEntry, userID: String) async throws {
        try validate(entry)
        try await repository.add(entry, userID: userID)
    }

    private func validate(_ entry: LiftEntry) throws {
        guard entry.reps > 0 else {
            throw AppError.invalidInput("Las repeticiones deben ser al menos 1.")
        }
    }
}

/// Actualiza un resultado existente.
struct UpdateLiftEntryUseCase: Sendable {
    private let repository: LiftEntryRepository
    init(repository: LiftEntryRepository) { self.repository = repository }

    func callAsFunction(_ entry: LiftEntry, userID: String) async throws {
        guard entry.reps > 0 else {
            throw AppError.invalidInput("Las repeticiones deben ser al menos 1.")
        }
        try await repository.update(entry, userID: userID)
    }
}

/// Elimina un resultado.
struct DeleteLiftEntryUseCase: Sendable {
    private let repository: LiftEntryRepository
    init(repository: LiftEntryRepository) { self.repository = repository }

    func callAsFunction(entryID: String, userID: String) async throws {
        try await repository.delete(entryID: entryID, userID: userID)
    }
}
