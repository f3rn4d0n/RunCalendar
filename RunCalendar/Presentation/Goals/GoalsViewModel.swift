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
    private let assessConfidence: AssessGoalConfidenceUseCase
    private let assessPace: AssessGoalPaceUseCase
    private let recommendGoal: RecommendGoalUseCase
    private let fetchAthleteMetrics: FetchAthleteMetricsUseCase
    /// Fuentes del valor "actual" para el progreso.
    private let racesViewModel: RacesViewModel
    private let trainingViewModel: TrainingViewModel

    /// Datos actuales del atleta (de Salud), para progreso de VO₂max/peso y recomendaciones.
    private(set) var metrics: AthleteMetrics = .empty

    init(
        userID: String,
        observeGoals: ObserveGoalsUseCase,
        addGoal: AddGoalUseCase,
        updateGoal: UpdateGoalUseCase,
        deleteGoal: DeleteGoalUseCase,
        assessProgress: AssessGoalProgressUseCase,
        assessConfidence: AssessGoalConfidenceUseCase,
        assessPace: AssessGoalPaceUseCase,
        recommendGoal: RecommendGoalUseCase,
        fetchAthleteMetrics: FetchAthleteMetricsUseCase,
        racesViewModel: RacesViewModel,
        trainingViewModel: TrainingViewModel
    ) {
        self.userID = userID
        self.observeGoals = observeGoals
        self.addGoal = addGoal
        self.updateGoal = updateGoal
        self.deleteGoal = deleteGoal
        self.assessProgress = assessProgress
        self.assessConfidence = assessConfidence
        self.assessPace = assessPace
        self.recommendGoal = recommendGoal
        self.fetchAthleteMetrics = fetchAthleteMetrics
        self.racesViewModel = racesViewModel
        self.trainingViewModel = trainingViewModel
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        metrics = (try? await fetchAthleteMetrics()) ?? .empty
        for await goals in observeGoals(userID: userID) {
            self.goals = goals
        }
    }

    /// Meta sugerida (editable) para un tipo/distancia, con datos reales.
    func recommendation(type: GoalType, distance: RaceDiscipline?) -> GoalRecommendation? {
        let records = PersonalRecords.compute(races: racesViewModel.races,
                                              sessions: trainingViewModel.sessions)
        return recommendGoal(type: type, distance: distance, records: records, metrics: metrics)
    }

    /// Progreso de una meta contra el dato actual disponible.
    func progress(for goal: Goal) -> GoalProgress {
        assessProgress(goal, current: currentValue(for: goal))
    }

    /// Confianza cualitativa de lograr la meta (nil = sin datos suficientes).
    func confidence(for goal: Goal) -> GoalConfidence? {
        assessConfidence(goal, current: currentValue(for: goal), records: records())
    }

    /// Frase de "coach" que explica, con datos reales, qué tan alcanzable es la meta. `nil` sin datos.
    func coachInsight(for goal: Goal) -> String? {
        guard let conf = confidence(for: goal) else { return nil }
        if conf == .achieved { return "¡Meta lograda! Mantén el hábito para no perderla." }

        let tone: String
        let prob: String
        switch conf {
        case .high:   tone = "alcanzable";            prob = "alta"
        case .medium: tone = "exigente pero posible"; prob = "media"
        default:      tone = "muy exigente";          prob = "baja"
        }

        var facts: [String] = []
        if let vo2 = metrics.vo2max { facts.append("un VO₂max de \(Goal.trim(vo2))") }
        if goal.type == .raceTime, let distance = goal.distance,
           let pr = records().first(where: { $0.distance != distance }) ?? records().first {
            facts.append("un PR de \(Goal.formatTime(pr.best.timeSeconds)) en \(pr.distance.displayName)")
        }
        let factsClause = facts.isEmpty ? "" : "Con \(facts.joined(separator: " y ")), "
        let weeksClause = goal.daysLeft().map { " en ~\(max(1, $0 / 7)) semanas" } ?? ""

        return "Tu objetivo es \(tone). \(factsClause)estimamos una probabilidad \(prob) de lograrlo"
            + "\(weeksClause), si mantienes la consistencia."
    }

    private func records() -> [PersonalRecord] {
        PersonalRecords.compute(races: racesViewModel.races, sessions: trainingViewModel.sessions)
    }

    /// Valor actual del atleta para la meta. `nil` si aún no hay dato.
    private func currentValue(for goal: Goal) -> Double? {
        currentValue(type: goal.type, distance: goal.distance)
    }

    private func currentValue(type: GoalType, distance: RaceDiscipline?) -> Double? {
        switch type {
        case .raceTime:
            guard let distance else { return nil }
            return records().first { $0.distance == distance }.map { Double($0.best.timeSeconds) }
        case .vo2max: return metrics.vo2max
        case .weight: return metrics.weightKg
        }
    }

    /// Ritmo semanal esperado para una meta (tipo/distancia/valor/fecha), con el dato actual real.
    /// Reactivo: la vista lo recalcula al cambiar la meta o la fecha.
    func expectedPace(type: GoalType, distance: RaceDiscipline?, target: Double, deadline: Date?) -> GoalPace? {
        assessPace(type: type, target: target,
                   current: currentValue(type: type, distance: distance), deadline: deadline)
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
