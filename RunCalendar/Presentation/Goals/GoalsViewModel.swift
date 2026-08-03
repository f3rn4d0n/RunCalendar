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
    private let describeWorkout: DescribeWorkoutUseCase
    private let suggestPlan: SuggestPlanUseCase

    /// Datos actuales del atleta (de Salud), para progreso de VO₂max/peso y recomendaciones.
    private(set) var metrics: AthleteMetrics = .empty

    /// Config del plan (días/semana + días preferidos). Persistida en UserDefaults; el plan en sí
    /// es derivado de tus metas y no se persiste (función pura de metas + volumen + config).
    ///
    /// Se lee aquí y **no** en el `init`: asignarla ahí dispara el `didSet`, que persistiría la
    /// config antes de que nadie la eligiera y haría creer a `seedPlanConfigIfNeeded()` que ya
    /// estaba configurada. Los observadores no corren para el valor inicial de la propiedad.
    // ponytail: config local; muévela a Firestore si importa el sync entre dispositivos.
    var planConfig = GoalsViewModel.loadPlanConfig() {
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
        describeWorkout: DescribeWorkoutUseCase,
        suggestPlan: SuggestPlanUseCase,
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
        self.describeWorkout = describeWorkout
        self.suggestPlan = suggestPlan
        self.racesViewModel = racesViewModel
        self.trainingViewModel = trainingViewModel
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
        return Calendar.app.isDate(last, equalTo: Date(), toGranularity: .weekOfYear)
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
            Usage.weeklyReviewSaved()
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
                                              sessions: trainingViewModel.sessions,
                                              splits: trainingViewModel.bestSplits)
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
        PersonalRecords.compute(races: racesViewModel.races, sessions: trainingViewModel.sessions,
                                splits: trainingViewModel.bestSplits)
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

    /// Sesiones de correr completadas desde una fecha (para medir la semana del plan).
    private func runningSessions(since start: Date) -> [TrainingSession] {
        trainingViewModel.sessions.filter {
            $0.completed && $0.type == .running && $0.date >= start && $0.date <= Date()
        }
    }

    /// Base de volumen del plan: el **máximo** de las últimas 4 semanas de calendario (la actual
    /// incluida, aunque vaya a medias).
    ///
    /// Antes era la suma móvil de 7 días, y eso convertía cualquier semana ligera en un escalón
    /// permanente hacia abajo: bajabas al 60% en una descarga, el motor leía "bajó de forma" y
    /// arrancaba la siguiente desde ese 60%. El plan peleaba contra su propia periodización.
    ///
    /// El máximo tiene la propiedad que hace falta: **sube cuando de verdad subes y no se hunde
    /// con una semana suave**. Si dejas de correr de verdad, las cuatro semanas caen y la base
    /// baja con ellas — que es lo correcto, solo que sin sobresaltos.
    private var runningWeeklyKm: Double {
        weeklyKmByWeek(lastWeeks: 4).max() ?? 0
    }

    /// Volumen semanal **crónico**: la media de las últimas 4 semanas. Denominador del ACWR, que el
    /// motor usa como techo. `nil` sin al menos dos semanas con datos — con una sola, "crónico" no
    /// significa nada.
    private var chronicWeeklyKm: Double? {
        let weeks = weeklyKmByWeek(lastWeeks: 4).filter { $0 > 0 }
        guard weeks.count >= 2 else { return nil }
        return weeks.reduce(0, +) / Double(weeks.count)
    }

    /// Km corridos en cada una de las últimas `lastWeeks` semanas de calendario, la actual primero.
    private func weeklyKmByWeek(lastWeeks: Int) -> [Double] {
        let cal = Calendar.app
        let thisWeek = Self.currentWeekStart()
        return (0..<lastWeeks).map { back in
            let start = cal.date(byAdding: .day, value: -7 * back, to: thisWeek) ?? thisWeek
            let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
            return trainingViewModel.sessions
                .filter { $0.completed && $0.type == .running && $0.date >= start && $0.date < end }
                .compactMap(\.distanceKm).reduce(0, +)
        }
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
    var currentPlan: TrainingPlan? { plan(weekOffset: 0) }

    /// El plan de una semana concreta: `0` la actual, `1` la próxima. `nil` si no hay meta ancla.
    ///
    /// El desfase existe porque planificar un sábado **no** es planificar el sábado: es planificar
    /// la semana que viene. Con `0` el plan solo propone los días que quedan de hoy en adelante y
    /// descuenta lo que ya corriste; con `1` la semana está entera por delante.
    func plan(weekOffset: Int) -> TrainingPlan? {
        guard let anchor = planAnchorGoal else { return nil }
        let start = Self.weekStart(offset: weekOffset)
        return generatePlan(.init(
            primary: anchor,
            secondaries: goals.filter { $0.id != anchor.id },
            config: planConfig,
            currentWeeklyKm: runningWeeklyKm,
            currentLongRunKm: runningLongestKm,
            races: racesViewModel.races,
            completed: runningSessions(since: start),
            chronicWeeklyKm: chronicWeeklyKm,
            weekStart: start
        ))
    }

    /// La misión de hoy (sesión planificada), si el plan pide entrenar hoy. `nil` en semana de
    /// lesión o enfermedad: empujar la sesión a alguien que ya dijo que no puede entrenar es
    /// exactamente el consejo que no queremos dar. Una descarga sí la conserva (se entrena menos,
    /// no se deja de entrenar).
    var todayMission: PlannedDay? {
        guard weekStatus?.pausesTraining != true else { return nil }
        return currentPlan?.today()
    }

    /// Estado de la semana en curso (lesión / enfermedad / descarga), o `nil` si es una semana
    /// normal. **Caduca solo**: se guarda junto a su `weekStart`, así que al cambiar de semana
    /// vuelve a `nil` sin tener que limpiar nada — que es el comportamiento correcto, una semana
    /// nueva arranca en blanco.
    ///
    /// ponytail: en UserDefaults como `planConfig`, y sin historial. Guardar las semanas lesionadas
    /// tendría sentido el día que exista adherencia histórica (que pide persistir el plan); hoy no
    /// hay quién las consuma.
    var weekStatus: WeekStatus? {
        get {
            let defaults = UserDefaults.standard
            guard let raw = defaults.string(forKey: Self.weekStatusKey),
                  let status = WeekStatus(rawValue: raw),
                  let saved = defaults.object(forKey: Self.weekStatusWeekKey) as? Date,
                  Calendar.current.isDate(saved, inSameDayAs: Self.currentWeekStart())
            else { return nil }
            return status
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue?.rawValue, forKey: Self.weekStatusKey)
            defaults.set(newValue == nil ? nil : Self.currentWeekStart(), forKey: Self.weekStatusWeekKey)
        }
    }

    /// Adherencia de **esta** semana: lo corrido vs. lo que el plan pide. `nil` sin plan
    /// **o si la semana está en pausa** (lesión / enfermedad / descarga).
    ///
    /// Compara totales de la semana (sesiones y km), no día por día: si el plan pedía series el
    /// martes y corriste el miércoles, cuenta igual — lo que importa es la carga, no el calendario.
    /// ponytail: solo la semana en curso. El plan no se persiste (es función de tu volumen de hoy),
    /// así que regenerarlo para semanas pasadas daría un plan distinto al que viste entonces;
    /// para adherencia histórica hay que guardar un snapshot del plan por semana.
    var weekAdherence: PlanAdherence? {
        guard let plan = currentPlan, weekStatus == nil else { return nil }
        let done = runningSessions(since: plan.weekStart)
        let hardDays = plan.days.filter { $0.kind.isHard }
        let todayPosition = PlannedDay.position(of: Calendar.current.component(.weekday, from: Date()))
        let hardWeekdays = Set(done.filter { isHard($0, plan: plan) }
            .map { Calendar.current.component(.weekday, from: $0.date) })
        return PlanAdherence(
            plannedSessions: plan.days.count,
            completedSessions: done.count,
            plannedKm: plan.totalKm,
            completedKm: done.compactMap(\.distanceKm).reduce(0, +),
            plannedHardSessions: hardDays.count,
            completedHardSessions: done.filter { isHard($0, plan: plan) }.count,
            missedHardDays: hardDays.filter {
                $0.weekPosition < todayPosition && !hardWeekdays.contains($0.weekday)
            }.count,
            completedMinutes: done.compactMap(\.durationMin).reduce(0, +)
        )
    }

    /// Km corridos por día en la semana de ese plan.
    ///
    /// Es lo que permite presentar la semana entera sin persistir nada: los días que ya pasaron se
    /// pintan con **lo que de verdad corriste** y los que quedan con lo que el plan propone. El
    /// pasado son hechos y el futuro una sugerencia, que es justo la diferencia que la vista debe
    /// dejar clara.
    func doneKmByWeekday(for plan: TrainingPlan) -> [Int: Double] {
        let cal = Calendar.app
        let weekEnd = cal.date(byAdding: .day, value: 7, to: plan.weekStart) ?? plan.weekStart
        let done = trainingViewModel.sessions.filter {
            $0.completed && $0.type == .running && $0.date >= plan.weekStart && $0.date < weekEnd
        }
        return Dictionary(grouping: done) { cal.component(.weekday, from: $0.date) }
            .mapValues { $0.compactMap(\.distanceKm).reduce(0, +) }
    }

    /// La semana día por día: qué pedía el plan y qué corriste. Vacío sin plan.
    /// Los días que aún no llegan salen como `.upcoming`: no se juzga lo que no tocó todavía.
    var weekOutcomes: [PlanDayOutcome] {
        guard let plan = currentPlan else { return [] }
        let done = Dictionary(grouping: runningSessions(since: plan.weekStart)) {
            Calendar.current.component(.weekday, from: $0.date)
        }
        let todayPosition = PlannedDay.position(of: Calendar.current.component(.weekday, from: Date()))
        // En orden real de la semana del usuario, no 1…7 (si empieza en lunes, el domingo va al final).
        return (1...7)
            .sorted { PlannedDay.position(of: $0) < PlannedDay.position(of: $1) }
            .map { weekday in
                let planned = plan.days.first { $0.weekday == weekday }
                let sessions = done[weekday] ?? []
                let km = sessions.compactMap(\.distanceKm).reduce(0, +)
                return PlanDayOutcome(
                    weekday: weekday,
                    plannedKind: planned?.kind,
                    plannedKm: planned?.targetKm,
                    doneKm: km,
                    doneMinutes: sessions.compactMap(\.durationMin).reduce(0, +),
                    status: PlanDayOutcome.status(
                        plannedKm: planned?.targetKm, doneKm: km,
                        hasPassed: PlannedDay.position(of: weekday) < todayPosition,
                        // Los días anteriores a que el plan existiera no se juzgan: lo que
                        // corriste ahí cuenta como hecho, y lo que no, como descanso. Marcarlos
                        // "fallado" o "extra" era pedir cuentas de un plan que no existía.
                        beforePlan: PlannedDay.position(of: weekday) < plan.plansFrom
                    )
                )
            }
    }

    /// RPE desde el que una sesión cuenta como de calidad (duro). 7 = "vigoroso" en la escala 1–10.
    private static let hardRPE = 7

    /// ¿Fue una sesión de calidad? **Unión de dos señales**, no una prioridad:
    ///
    /// - el **tipo que el plan pedía ese día**: unas series bien controladas pueden salir en RPE 6
    ///   y siguen siendo calidad, así que el RPE solo se quedaría corto;
    /// - el **RPE ≥ 7**, que no depende del día: si moviste el tempo, o si repetiste las series en
    ///   un día fácil, la intensidad ocurrió y el plan por sí solo no la vería.
    ///
    /// Suma de más a propósito: para el aviso de carga interesa **toda** la intensidad de la
    /// semana, venga del plan o no (un trail duro cuenta como carga aunque no sustituya al tempo).
    /// El límite queda documentado en `docs/adherencia.md`.
    private func isHard(_ session: TrainingSession, plan: TrainingPlan) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: session.date)
        let plannedHard = plan.days.first { $0.weekday == weekday }?.kind.isHard ?? false
        return plannedHard || (session.rpe ?? 0) >= Self.hardRPE
    }

    /// Explicación pedagógica de una sesión planificada (qué es, cómo, para qué, por qué ese número).
    func guide(for day: PlannedDay) -> WorkoutGuide { describeWorkout(day) }

    // MARK: - Campaña (Fase 3)

    /// La campaña en curso: tu meta principal convertida en misiones de esta semana. `nil` si no
    /// hay meta que la ancle. Se arma de lo que ya existe (meta ancla + plan + adherencia + metas
    /// secundarias); no se guarda nada nuevo.
    var campaign: Campaign? {
        guard let anchor = planAnchorGoal else { return nil }
        // En semana pausada no hay `weekAdherence`, así que las misiones del plan desaparecen solas
        // y quedan las de las metas: no se marca como fallado lo que no se estaba midiendo.
        var missions = weekAdherence.map(Campaign.planMissions) ?? []
        // Las metas secundarias entran como misiones propias: son las victorias que no salen de
        // correr (bajar de peso, bajar la FC en reposo) y también acercan a la principal.
        for goal in goals where goal.id != anchor.id {
            let progress = progress(for: goal)
            missions.append(CampaignMission(
                title: "\(goal.type.displayName): \(Goal.format(goal.targetValue, type: goal.type))",
                detail: progress.deltaText,
                isDone: progress.achieved,
                systemImage: goal.type.systemImage
            ))
        }
        return Campaign(
            title: campaignTitle(for: anchor),
            goalHeadline: anchor.type == .raceTime && anchor.distance != nil
                ? "\(anchor.distance!.displayName) en \(Goal.formatTime(Int(anchor.targetValue)))"
                : "\(anchor.type.displayName): \(Goal.format(anchor.targetValue, type: anchor.type))",
            deadline: anchor.deadline ?? targetRace(for: anchor)?.date,
            missions: missions
        )
    }

    /// Nombre de la campaña: el de la carrera objetivo si la hay (es lo que el atleta tiene en la
    /// cabeza), si no la meta misma.
    private func campaignTitle(for anchor: Goal) -> String {
        targetRace(for: anchor)?.name ?? anchor.type.displayName
    }

    /// La carrera que persigue esta meta: la próxima inscrita o prioritaria de esa distancia.
    private func targetRace(for anchor: Goal) -> Race? {
        let today = Calendar.current.startOfDay(for: Date())
        let upcoming = racesViewModel.races
            .filter { $0.status == .upcoming && $0.date >= today }
            .filter { anchor.distance == nil || $0.discipline == anchor.distance }
            .sorted { $0.date < $1.date }
        return upcoming.first { $0.isRegistered || $0.isPriority } ?? upcoming.first
    }

    /// Sugerencia de plan desde tu historial de carreras (días/semana, días y meta de volumen).
    /// `nil` si aún no hay historial suficiente. Solo calcula; no aplica nada.
    func planSuggestion() -> PlanSuggestion? {
        suggestPlan(runningSessions: runningSessions(withinDays: 42))
    }

    /// Siembra la config del plan desde tu historial la **primera** vez que hay datos.
    ///
    /// Sin esto todo el mundo empieza en 3 días/semana, que es un número inventado — y chirría
    /// porque el resto del plan **sí** sale de tus datos (volumen, tirada larga, tus carreras). La
    /// frecuencia era lo único adivinado, y encima es la que decide la estructura de la semana: con
    /// pocos días y volumen alto las sesiones de calidad topan y el plan **descarta kilómetros en
    /// silencio** (40 km en 3 días acaban en 37, bajo el umbral que dispara el aviso).
    ///
    /// No hace nada si ya hay config guardada —aunque sea porque elegiste 3 a mano— ni si todavía
    /// no hay historial suficiente, que es el único caso donde el 3 de fábrica sigue siendo lo
    /// razonable. Se llama al llegar sesiones nuevas y es idempotente.
    ///
    /// Siembra **solo la config**, no la meta de volumen que sí crea `applyPlanSuggestion`: ajustar
    /// tus días es reversible con un stepper, crearte una meta a tus espaldas no.
    func seedPlanConfigIfNeeded() {
        guard !Self.hasSavedPlanConfig, let suggestion = planSuggestion() else { return }
        planConfig = suggestion.config   // el `didSet` lo persiste, y con eso deja de sembrar
    }

    private static var hasSavedPlanConfig: Bool {
        UserDefaults.standard.object(forKey: planDaysKey) != nil
    }

    /// Aplica una sugerencia: fija la config del plan y crea/actualiza la meta de volumen que lo
    /// ancla. El usuario puede editar ambos después.
    func applyPlanSuggestion(_ suggestion: PlanSuggestion) async {
        planConfig = suggestion.config
        if var goal = goals.first(where: { $0.type == .weeklyVolume }) {
            goal.targetValue = suggestion.weeklyVolumeTarget
            if goal.deadline == nil { goal.deadline = suggestion.deadline }
            _ = await save(goal, isNew: false)
        } else {
            let goal = Goal(type: .weeklyVolume, targetValue: suggestion.weeklyVolumeTarget,
                            deadline: suggestion.deadline)
            _ = await save(goal, isNew: true)   // save() captura el startValue actual
        }
    }

    private static func currentWeekStart(_ now: Date = Date()) -> Date {
        Calendar.app.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }

    /// Inicio de la semana `offset` semanas adelante (0 = la actual).
    private static func weekStart(offset: Int, now: Date = Date()) -> Date {
        let start = currentWeekStart(now)
        return Calendar.app.date(byAdding: .day, value: 7 * offset, to: start) ?? start
    }

    private static let weekStatusKey = "week.status"
    private static let weekStatusWeekKey = "week.status.weekStart"
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
