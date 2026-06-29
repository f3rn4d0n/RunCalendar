import Foundation

/// Observa las carreras del usuario en tiempo real.
struct ObserveRacesUseCase: Sendable {
    private let repository: RaceRepository
    init(repository: RaceRepository) { self.repository = repository }

    func callAsFunction(userID: String) -> AsyncStream<[Race]> {
        repository.racesStream(userID: userID)
    }
}

/// Agrega una carrera nueva.
struct AddRaceUseCase: Sendable {
    private let repository: RaceRepository
    init(repository: RaceRepository) { self.repository = repository }

    func callAsFunction(_ race: Race, userID: String) async throws {
        try validate(race)
        try await repository.add(race, userID: userID)
    }

    private func validate(_ race: Race) throws {
        guard !race.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AppError.invalidInput("El nombre de la carrera es obligatorio.")
        }
    }
}

/// Actualiza una carrera existente.
struct UpdateRaceUseCase: Sendable {
    private let repository: RaceRepository
    init(repository: RaceRepository) { self.repository = repository }

    func callAsFunction(_ race: Race, userID: String) async throws {
        guard !race.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AppError.invalidInput("El nombre de la carrera es obligatorio.")
        }
        try await repository.update(race, userID: userID)
    }
}

/// Elimina una carrera.
struct DeleteRaceUseCase: Sendable {
    private let repository: RaceRepository
    init(repository: RaceRepository) { self.repository = repository }

    func callAsFunction(raceID: String, userID: String) async throws {
        try await repository.delete(raceID: raceID, userID: userID)
    }
}
