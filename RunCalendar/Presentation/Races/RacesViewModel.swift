import Foundation
import Observation

@MainActor
@Observable
final class RacesViewModel {

    private(set) var races: [Race] = []
    var errorMessage: String?
    private var hasStarted = false

    let userID: String
    private let observeRaces: ObserveRacesUseCase
    private let addRace: AddRaceUseCase
    private let updateRace: UpdateRaceUseCase
    private let deleteRace: DeleteRaceUseCase

    init(
        userID: String,
        observeRaces: ObserveRacesUseCase,
        addRace: AddRaceUseCase,
        updateRace: UpdateRaceUseCase,
        deleteRace: DeleteRaceUseCase
    ) {
        self.userID = userID
        self.observeRaces = observeRaces
        self.addRace = addRace
        self.updateRace = updateRace
        self.deleteRace = deleteRace
    }

    var upcomingRaces: [Race] { races.filter { $0.status == .upcoming } }
    var completedRaces: [Race] { races.filter { $0.status == .completed } }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        for await items in observeRaces(userID: userID) {
            races = items
        }
    }

    func save(_ race: Race, isNew: Bool) async -> Bool {
        do {
            if isNew {
                try await addRace(race, userID: userID)
            } else {
                try await updateRace(race, userID: userID)
            }
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ race: Race) async {
        do {
            try await deleteRace(raceID: race.id, userID: userID)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
