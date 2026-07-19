import Foundation
import Observation

/// Objetivos del atleta (Fase 1). Persiste metas y calcula su progreso contra los datos
/// reales: hoy, las metas de **tiempo** se miden contra tus PRs. VO₂max y peso (de HealthKit)
/// se cablean en el siguiente paso; mientras, muestran "—".
@MainActor
@Observable
final class GoalsViewModel {

    private(set) var goals: [Goal] = []
    var errorMessage: String?
    private var hasStarted = false

    let userID: String
    private let observeGoals: ObserveGoalsUseCase
    private let addGoal: AddGoalUseCase
    private let updateGoal: UpdateGoalUseCase
    private let deleteGoal: DeleteGoalUseCase
    private let assessProgress: AssessGoalProgressUseCase
    /// Fuentes del valor "actual" para el progreso.
    private let racesViewModel: RacesViewModel
    private let trainingViewModel: TrainingViewModel

    init(
        userID: String,
        observeGoals: ObserveGoalsUseCase,
        addGoal: AddGoalUseCase,
        updateGoal: UpdateGoalUseCase,
        deleteGoal: DeleteGoalUseCase,
        assessProgress: AssessGoalProgressUseCase,
        racesViewModel: RacesViewModel,
        trainingViewModel: TrainingViewModel
    ) {
        self.userID = userID
        self.observeGoals = observeGoals
        self.addGoal = addGoal
        self.updateGoal = updateGoal
        self.deleteGoal = deleteGoal
        self.assessProgress = assessProgress
        self.racesViewModel = racesViewModel
        self.trainingViewModel = trainingViewModel
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        for await goals in observeGoals(userID: userID) {
            self.goals = goals
        }
    }

    /// Progreso de una meta contra el dato actual disponible.
    func progress(for goal: Goal) -> GoalProgress {
        assessProgress(goal, current: currentValue(for: goal))
    }

    /// Valor actual del atleta para la meta. `nil` si aún no hay dato.
    private func currentValue(for goal: Goal) -> Double? {
        switch goal.type {
        case .raceTime:
            guard let distance = goal.distance else { return nil }
            let records = PersonalRecords.compute(races: racesViewModel.races,
                                                  sessions: trainingViewModel.sessions)
            return records.first { $0.distance == distance }.map { Double($0.best.timeSeconds) }
        case .vo2max, .weight:
            return nil   // ponytail: se cablea desde HealthKit en el siguiente PR
        }
    }

    func save(_ goal: Goal, isNew: Bool) async -> Bool {
        var goal = goal
        // Captura el punto de partida al crear, para que la barra de progreso tenga base.
        if isNew, goal.startValue == nil { goal.startValue = currentValue(for: goal) }
        do {
            if isNew { try await addGoal(goal, userID: userID) }
            else { try await updateGoal(goal, userID: userID) }
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ goal: Goal) async {
        do { try await deleteGoal(goalID: goal.id, userID: userID) }
        catch { errorMessage = error.localizedDescription }
    }
}
