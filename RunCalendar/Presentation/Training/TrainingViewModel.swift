import Foundation
import Observation

@MainActor
@Observable
final class TrainingViewModel {

    private(set) var sessions: [TrainingSession] = []
    var errorMessage: String?
    private var hasStarted = false

    let userID: String
    private let observeTrainings: ObserveTrainingsUseCase
    private let addTraining: AddTrainingUseCase
    private let updateTraining: UpdateTrainingUseCase
    private let deleteTraining: DeleteTrainingUseCase

    init(
        userID: String,
        observeTrainings: ObserveTrainingsUseCase,
        addTraining: AddTrainingUseCase,
        updateTraining: UpdateTrainingUseCase,
        deleteTraining: DeleteTrainingUseCase
    ) {
        self.userID = userID
        self.observeTrainings = observeTrainings
        self.addTraining = addTraining
        self.updateTraining = updateTraining
        self.deleteTraining = deleteTraining
    }

    func sessions(of type: TrainingType) -> [TrainingSession] {
        sessions.filter { $0.type == type }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        for await items in observeTrainings(userID: userID) {
            sessions = items
        }
    }

    func save(_ session: TrainingSession, isNew: Bool) async -> Bool {
        do {
            if isNew {
                try await addTraining(session, userID: userID)
            } else {
                try await updateTraining(session, userID: userID)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func toggleCompleted(_ session: TrainingSession) async {
        var updated = session
        updated.completed.toggle()
        _ = await save(updated, isNew: false)
    }

    func delete(_ session: TrainingSession) async {
        do {
            try await deleteTraining(sessionID: session.id, userID: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
