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
    private let saveMeasure: SaveBodyMeasureUseCase
    private let fetchMeasureHistory: FetchBodyMeasureHistoryUseCase
    private let saveBodyLog: SaveBodyLogUseCase
    private let fetchBodyLogs: FetchBodyLogsUseCase
    private let assessRecomposition: AssessRecompositionUseCase
    /// Fuentes del valor "actual" para el progreso.
    private let racesViewModel: RacesViewModel
    private let trainingViewModel: TrainingViewModel
    private let generatePlan: GeneratePlanUseCase
    private let inferPrimary: InferPrimaryGoalUseCase

    /// Datos actuales del atleta (de Salud), para progreso de VO₂max/peso y recomendaciones.
    private(set) var metrics: AthleteMetrics = .empty

    /// Config del plan (días/semana + días preferidos). Persistida en UserDefaults; el plan en sí
    /// es derivado de tus metas y no se persiste (función pura de metas + volumen + config).
    // ponytail: config local; muévela a Firestore si importa el sync entre dispositivos.
    var planConfig = PlanConfig(daysPerWeek: 3) {
        didSet { Self.savePlanConfig(planConfig) }
    }

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
        saveMeasure: SaveBodyMeasureUseCase,
        fetchMeasureHistory: FetchBodyMeasureHistoryUseCase,
        saveBodyLog: SaveBodyLogUseCase,
        fetchBodyLogs: FetchBodyLogsUseCase,
        assessRecomposition: AssessRecompositionUseCase,
        generatePlan: GeneratePlanUseCase,
        inferPrimary: InferPrimaryGoalUseCase,
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
        self.saveMeasure = saveMeasure
        self.fetchMeasureHistory = fetchMeasureHistory
        self.saveBodyLog = saveBodyLog
        self.fetchBodyLogs = fetchBodyLogs
        self.assessRecomposition = assessRecomposition
        self.generatePlan = generatePlan
        self.inferPrimary = inferPrimary
        self.racesViewModel = racesViewModel
        self.trainingViewModel = trainingViewModel
        self.planConfig = Self.loadPlanConfig()
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await refreshBody()
        for await goals in observeGoals(userID: userID) {
            self.goals = goals
        }
    }

    // MARK: - Seguimiento corporal (peso, cintura y review dominical)

    /// Cada cuántos días pedir el peso. ponytail: constante; hazla preferencia si alguien la pide.
    static let weightLogIntervalDays = 2

    /// Historiales leídos de Salud (más reciente primero), por medida.
    private(set) var history: [BodyMeasure: [MeasurementEntry]] = [:]
    /// Reviews dominicales (de Firestore), más reciente primero.
    private(set) var bodyLogs: [BodyLog] = []
    /// Día en el que descartaste la tarjeta de "registra tu peso" (vuelve al día siguiente).
    var weightPromptDismissedOn: Date?
    /// Día en el que descartaste la tarjeta del review semanal.
    var reviewPromptDismissedOn: Date?

    var canLogMeasures: Bool { saveMeasure.isAvailable }

    /// La meta de peso activa (solo hay sentido en tener una).
    var weightGoal: Goal? { goals.first { $0.type == .weight } }

    func history(for measure: BodyMeasure) -> [MeasurementEntry] { history[measure] ?? [] }

    /// Registro más reciente de una medida (de Salud).
    func latest(_ measure: BodyMeasure) -> MeasurementEntry? { history(for: measure).first }

    /// Peso más reciente. Atajo, es el que más se consulta.
    var latestWeight: MeasurementEntry? { latest(.weight) }

    /// ¿Toca registrar peso? Sí si hay meta de peso y el último registro es de hace
    /// `weightLogIntervalDays` días o más (o no hay ninguno), y no descartaste la tarjeta hoy.
    var needsWeightLog: Bool {
        guard canLogMeasures, weightGoal != nil else { return false }
        if let dismissed = weightPromptDismissedOn, Calendar.current.isDateInToday(dismissed) { return false }
        guard let last = latestWeight?.date else { return true }
        return days(since: last) >= Self.weightLogIntervalDays
    }

    /// ¿Toca el review semanal? Solo domingo, si no lo registraste ya esta semana
    /// y no descartaste la tarjeta hoy. El domingo es el día del review en el Manual.
    var needsWeeklyReview: Bool {
        guard Calendar.current.component(.weekday, from: Date()) == 1 else { return false }
        if let dismissed = reviewPromptDismissedOn, Calendar.current.isDateInToday(dismissed) { return false }
        return !hasReviewThisWeek
    }

    /// ¿Ya hay un review en la semana en curso?
    var hasReviewThisWeek: Bool {
        guard let last = bodyLogs.first?.date else { return false }
        return Calendar.current.isDate(last, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Aviso de recomposición: peso estancado pero cintura bajando. `nil` si no aplica
    /// o si faltan datos de alguna de las dos series.
    var recomposition: AssessRecompositionUseCase.Trend? {
        let trend = assessRecomposition(weights: history(for: .weight), waists: history(for: .waist))
        return trend?.isRecomposition == true ? trend : nil
    }

    /// Guarda una medida en Salud y refresca (así el progreso de la meta se mueve solo).
    func logMeasure(_ measure: BodyMeasure, value: Double, date: Date = Date()) async -> Bool {
        errorMessage = nil   // si ya diste el permiso, el reintento no debe seguir mostrando el error
        do {
            try await saveMeasure(measure, value: value, date: date)
            await refreshBody()
            Haptics.success()
            return true
        } catch {
            // El error real (incluye la ruta para activar el permiso en Salud).
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Guarda el review dominical completo: las medidas van a Salud y lo subjetivo a Firestore.
    /// `weight`/`waist` en `nil` = no lo capturaste, se deja sin tocar.
    func saveReview(weight: Double?, waist: Double?, energy: Int, hunger: Int,
                    notes: String, date: Date = Date()) async -> Bool {
        errorMessage = nil
        do {
            if let weight { try await saveMeasure(.weight, value: weight, date: date) }
            if let waist { try await saveMeasure(.waist, value: waist, date: date) }
            try await saveBodyLog(
                BodyLog(date: date, energy: energy, hunger: hunger, notes: notes),
                userID: userID
            )
            await refreshBody()
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Relee de Salud las medidas y de Firestore los reviews.
    func refreshBody() async {
        metrics = (try? await fetchAthleteMetrics()) ?? .empty
        for measure in BodyMeasure.allCases {
            history[measure] = (try? await fetchMeasureHistory(measure)) ?? []
        }
        bodyLogs = (try? await fetchBodyLogs(userID: userID)) ?? []
    }

    private func days(since date: Date) -> Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: date),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
    }

    /// Meta sugerida (editable) para un tipo/distancia, con datos reales.
    func recommendation(type: GoalType, distance: RaceDiscipline?) -> GoalRecommendation? {
        let records = PersonalRecords.compute(races: racesViewModel.races,
                                              sessions: trainingViewModel.sessions)
        // Las metas auto-medibles se sugieren desde tu valor actual real (volumen, tirada, FC).
        return recommendGoal(type: type, distance: distance, records: records, metrics: metrics,
                             current: currentValue(type: type, distance: distance))
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
        // La báscula estancada mientras la cintura baja es progreso real, no falta de él.
        // Se dice antes que nada: es justo cuando la barra de progreso parece decir lo contrario.
        if goal.type == .weight, let trend = recomposition {
            let waist = String(format: "%.1f", abs(trend.waistDeltaCm))
            return "Tu peso casi no se movió, pero tu cintura bajó \(waist) cm: estás ganando "
                + "músculo mientras pierdes grasa. La báscula no lo ve; vas bien."
        }

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
        case .vo2max:    return metrics.vo2max
        case .weight:    return metrics.weightKg
        case .restingHR: return metrics.restingHR
        // Volumen y tirada larga salen de las sesiones (que ya incluyen lo importado de Salud),
        // el mismo origen que usa la carga de ACWR: así una meta y la carga nunca se contradicen.
        case .weeklyVolume: return weeklyVolumeKm
        case .longRun:      return longestRunKm
        }
    }

    /// Kilómetros completados en los últimos 7 días.
    private var weeklyVolumeKm: Double? {
        distanceSessions(withinDays: 7).compactMap(\.distanceKm).reduce(0, +)
    }

    /// La corrida más larga de las últimas 8 semanas. Ventana y no histórico: la meta mide
    /// tu capacidad *actual*, no una tirada de hace dos años.
    // ponytail: 8 semanas ≈ un bloque de entrenamiento; ajústalo si el bloque es más largo.
    private var longestRunKm: Double? {
        distanceSessions(withinDays: 56).compactMap(\.distanceKm).max()
    }

    /// Sesiones completadas con distancia dentro de la ventana (correr, caminar, senderismo).
    private func distanceSessions(withinDays days: Int) -> [TrainingSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return trainingViewModel.sessions.filter {
            $0.completed && $0.type.tracksDistance && $0.date >= cutoff && $0.date <= Date()
        }
    }

    /// Volumen del **plan de carrera**: solo sesiones de correr (no camina/senderismo). Un plan de
    /// carrera se construye sobre tu volumen de correr; contar caminatas lo inflaba y disparaba
    /// avisos falsos ("no cabe en 3 días") aunque corrieras poco.
    private func runningSessions(withinDays days: Int) -> [TrainingSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return trainingViewModel.sessions.filter {
            $0.completed && $0.type == .running && $0.date >= cutoff && $0.date <= Date()
        }
    }

    private var runningWeeklyKm: Double {
        runningSessions(withinDays: 7).compactMap(\.distanceKm).reduce(0, +)
    }

    private var runningLongestKm: Double? {
        runningSessions(withinDays: 56).compactMap(\.distanceKm).max()
    }

    /// Ritmo semanal esperado para una meta (tipo/distancia/valor/fecha), con el dato actual real.
    /// Reactivo: la vista lo recalcula al cambiar la meta o la fecha.
    func expectedPace(type: GoalType, distance: RaceDiscipline?, target: Double, deadline: Date?) -> GoalPace? {
        assessPace(type: type, target: target,
                   current: currentValue(type: type, distance: distance), deadline: deadline)
    }

    // MARK: - Plan de entrenamiento (Fase 3)

    /// Meta que ancla el plan: la principal inferida (driver: tiempo/VO₂max), o —si no hay driver—
    /// una de volumen/tirada larga, que también sirve para dar forma a la semana.
    var planAnchorGoal: Goal? {
        inferPrimary(goals) ?? goals.first { $0.type.planRole == .parameter }
    }

    /// Plan de la semana, derivado de tus metas + volumen actual + config. `nil` si no hay meta
    /// que lo ancle. Reactivo: se recalcula al cambiar metas, sesiones o config.
    var currentPlan: TrainingPlan? {
        guard let anchor = planAnchorGoal else { return nil }
        return generatePlan(.init(
            primary: anchor,
            secondaries: goals.filter { $0.id != anchor.id },
            config: planConfig,
            currentWeeklyKm: runningWeeklyKm,
            currentLongRunKm: runningLongestKm,
            weekStart: Self.currentWeekStart()
        ))
    }

    /// La misión de hoy (sesión planificada), si el plan pide entrenar hoy.
    var todayMission: PlannedDay? { currentPlan?.today() }

    private static func currentWeekStart(_ now: Date = Date()) -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }

    private static let planDaysKey = "plan.daysPerWeek"
    private static let planWeekdaysKey = "plan.weekdays"

    private static func savePlanConfig(_ config: PlanConfig) {
        UserDefaults.standard.set(config.daysPerWeek, forKey: planDaysKey)
        UserDefaults.standard.set(config.preferredWeekdays, forKey: planWeekdaysKey)
    }

    private static func loadPlanConfig() -> PlanConfig {
        let defaults = UserDefaults.standard
        let days = defaults.object(forKey: planDaysKey) as? Int ?? 3
        let weekdays = defaults.array(forKey: planWeekdaysKey) as? [Int] ?? []
        return PlanConfig(daysPerWeek: days, preferredWeekdays: weekdays)
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
