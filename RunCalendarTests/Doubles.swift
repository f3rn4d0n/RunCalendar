import Foundation
@testable import RunCalendar

/// Dobles de los repositorios (capa Data) para poder construir ViewModels en una prueba.
///
/// Los ViewModels ya reciben **casos de uso**, y los casos de uso reciben **protocolos**: no hay
/// que tocar producción para llegar aquí, solo implementar los protocolos con datos sembrados.
///
/// ponytail: sin candados ni actores. Las suites que los usan son `.serialized` y todo corre en el
/// MainActor, así que sincronizarlos sería ceremonia sin nadie a quien proteger. Si algún día hay
/// una prueba concurrente que los comparta, hazlos `actor` — y ahí se verá el error de compilación.

/// Stream que emite **una vez** lo sembrado y cierra.
///
/// Es lo que hace que `await viewModel.start()` termine: contra Firestore el stream queda abierto
/// escuchando cambios, así que un doble que no cierre colgaría la prueba para siempre.
private func onceStream<T: Sendable>(_ items: T) -> AsyncStream<T> {
    AsyncStream { continuation in
        continuation.yield(items)
        continuation.finish()
    }
}

/// Error genérico para probar los caminos de fallo (que el ViewModel llene `errorMessage`).
struct FakeFailure: LocalizedError {
    var errorDescription: String? { "Falló a propósito" }
}

// MARK: - Metas

final class FakeGoalRepository: GoalRepository, @unchecked Sendable {
    var goals: [Goal]
    var failure: Error?

    private(set) var added: [Goal] = []
    private(set) var updated: [Goal] = []
    private(set) var deleted: [String] = []

    init(_ goals: [Goal] = []) { self.goals = goals }

    func goalsStream(userID: String) -> AsyncStream<[Goal]> { onceStream(goals) }

    func add(_ goal: Goal, userID: String) async throws {
        if let failure { throw failure }
        added.append(goal)
    }
    func update(_ goal: Goal, userID: String) async throws {
        if let failure { throw failure }
        updated.append(goal)
    }
    func delete(goalID: String, userID: String) async throws {
        if let failure { throw failure }
        deleted.append(goalID)
    }
}

// MARK: - Carreras

final class FakeRaceRepository: RaceRepository, @unchecked Sendable {
    var races: [Race]
    var failure: Error?

    private(set) var added: [Race] = []
    private(set) var updated: [Race] = []
    private(set) var deleted: [String] = []

    init(_ races: [Race] = []) { self.races = races }

    func racesStream(userID: String) -> AsyncStream<[Race]> { onceStream(races) }

    func add(_ race: Race, userID: String) async throws {
        if let failure { throw failure }
        added.append(race)
    }
    func update(_ race: Race, userID: String) async throws {
        if let failure { throw failure }
        updated.append(race)
    }
    func delete(raceID: String, userID: String) async throws {
        if let failure { throw failure }
        deleted.append(raceID)
    }
}

// MARK: - Entrenamientos

final class FakeTrainingRepository: TrainingRepository, @unchecked Sendable {
    var sessions: [TrainingSession]
    var failure: Error?

    private(set) var added: [TrainingSession] = []
    private(set) var updated: [TrainingSession] = []
    private(set) var deleted: [String] = []

    init(_ sessions: [TrainingSession] = []) { self.sessions = sessions }

    func trainingsStream(userID: String) -> AsyncStream<[TrainingSession]> { onceStream(sessions) }

    func add(_ session: TrainingSession, userID: String) async throws {
        if let failure { throw failure }
        added.append(session)
    }
    func update(_ session: TrainingSession, userID: String) async throws {
        if let failure { throw failure }
        updated.append(session)
    }
    func delete(sessionID: String, userID: String) async throws {
        if let failure { throw failure }
        deleted.append(sessionID)
    }
}

// MARK: - Salud

/// Por defecto se comporta como un dispositivo **sin** datos de salud: es el caso que más
/// importa no romper (Mac, o alguien que negó el permiso). Cada prueba siembra lo que necesite.
final class FakeHealthRepository: HealthRepository, @unchecked Sendable {
    var available = false
    var metrics: AthleteMetrics = .empty
    var measures: [BodyMeasure: [MeasurementEntry]] = [:]
    var workouts: [HealthWorkout] = []
    var splits: [BestSplit] = []
    var saveFailure: Error?

    private(set) var savedMeasures: [(measure: BodyMeasure, value: Double, date: Date)] = []

    func isAvailable() -> Bool { available }
    func requestAuthorization() async -> Bool { available }

    func fetchAthleteMetrics() async throws -> AthleteMetrics { metrics }
    func fetchRecentWorkouts(days: Int) async throws -> [HealthWorkout] { workouts }
    func fetchBestSplits(distancesKm: [Double]) async throws -> [BestSplit] { splits }

    func fetchMeasureHistory(_ measure: BodyMeasure, days: Int) async throws -> [MeasurementEntry] {
        measures[measure] ?? []
    }

    func saveMeasure(_ measure: BodyMeasure, value: Double, date: Date) async throws {
        if let saveFailure { throw saveFailure }
        savedMeasures.append((measure, value, date))
        measures[measure, default: []].insert(MeasurementEntry(date: date, value: value), at: 0)
    }

    // Lo que ninguna prueba de ViewModel consulta todavía: sin datos, como un dispositivo sin Salud.
    func fetchSummary(weeks: Int) async throws -> FitnessSummary { throw FakeFailure() }
    func fetchRecovery() async throws -> RecoverySnapshot? { nil }
    func fetchRecoveryTrend(days: Int) async throws -> RecoveryTrend? { nil }
    func fetchWorkload() async throws -> WorkloadInput? { nil }
    func fetchFitnessTrend(weeks: Int) async throws -> FitnessTrend? { nil }
    func fetchRoute(onDay date: Date, distanceKm: Double?) async throws -> WorkoutRoute? { nil }
    func workoutUpdates() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

// MARK: - Review dominical, clima y calendario

final class FakeBodyLogRepository: BodyLogRepository, @unchecked Sendable {
    var logs: [BodyLog] = []
    var failure: Error?

    private(set) var saved: [BodyLog] = []

    func save(_ log: BodyLog, userID: String) async throws {
        if let failure { throw failure }
        saved.append(log)
        logs.insert(log, at: 0)
    }
    func fetchRecent(days: Int, userID: String) async throws -> [BodyLog] { logs }
}

final class FakeWeatherRepository: WeatherRepository, @unchecked Sendable {
    var result: RaceWeather?
    var failure: Error?

    func weather(latitude: Double, longitude: Double, date: Date) async throws -> RaceWeather? {
        if let failure { throw failure }
        return result
    }
}

final class FakeCalendarRepository: CalendarRepository, @unchecked Sendable {
    var failure: Error?
    private(set) var events: [CalendarEvent] = []

    func add(_ event: CalendarEvent) async throws {
        if let failure { throw failure }
        events.append(event)
    }
}

// MARK: - Montaje

/// Arma los tres ViewModels cableados a dobles, igual que hace `AppContainer` con las
/// implementaciones de verdad. Guarda los dobles para poder sembrarlos y espiarlos.
///
/// `start()` de cada uno termina solo porque los streams de los dobles cierran tras emitir.
@MainActor
struct TestApp {
    let goalRepo: FakeGoalRepository
    let raceRepo: FakeRaceRepository
    let trainingRepo: FakeTrainingRepository
    let healthRepo: FakeHealthRepository
    let bodyLogRepo: FakeBodyLogRepository
    let weatherRepo: FakeWeatherRepository
    let calendarRepo: FakeCalendarRepository

    let races: RacesViewModel
    let training: TrainingViewModel
    let goals: GoalsViewModel

    init(goals seededGoals: [Goal] = [], races seededRaces: [Race] = [],
         sessions: [TrainingSession] = [], userID: String = "test-user") {
        clearPersistedDefaults()
        goalRepo = FakeGoalRepository(seededGoals)
        raceRepo = FakeRaceRepository(seededRaces)
        trainingRepo = FakeTrainingRepository(sessions)
        healthRepo = FakeHealthRepository()
        bodyLogRepo = FakeBodyLogRepository()
        weatherRepo = FakeWeatherRepository()
        calendarRepo = FakeCalendarRepository()

        races = RacesViewModel(
            userID: userID,
            observeRaces: ObserveRacesUseCase(repository: raceRepo),
            addRace: AddRaceUseCase(repository: raceRepo),
            updateRace: UpdateRaceUseCase(repository: raceRepo),
            deleteRace: DeleteRaceUseCase(repository: raceRepo),
            fetchWeather: FetchRaceWeatherUseCase(repository: weatherRepo),
            addToCalendar: AddToCalendarUseCase(repository: calendarRepo)
        )
        training = TrainingViewModel(
            userID: userID,
            observeTrainings: ObserveTrainingsUseCase(repository: trainingRepo),
            addTraining: AddTrainingUseCase(repository: trainingRepo),
            updateTraining: UpdateTrainingUseCase(repository: trainingRepo),
            deleteTraining: DeleteTrainingUseCase(repository: trainingRepo),
            fetchRecentWorkouts: FetchRecentWorkoutsUseCase(repository: healthRepo),
            fetchBestSplits: FetchBestSplitsUseCase(repository: healthRepo),
            fetchWorkoutRoute: FetchWorkoutRouteUseCase(repository: healthRepo),
            fetchWeather: FetchRaceWeatherUseCase(repository: weatherRepo)
        )
        goals = GoalsViewModel(
            userID: userID,
            observeGoals: ObserveGoalsUseCase(repository: goalRepo),
            addGoal: AddGoalUseCase(repository: goalRepo),
            updateGoal: UpdateGoalUseCase(repository: goalRepo),
            deleteGoal: DeleteGoalUseCase(repository: goalRepo),
            assessProgress: AssessGoalProgressUseCase(),
            assessConfidence: AssessGoalConfidenceUseCase(),
            assessPace: AssessGoalPaceUseCase(),
            recommendGoal: RecommendGoalUseCase(),
            fetchAthleteMetrics: FetchAthleteMetricsUseCase(repository: healthRepo),
            saveMeasure: SaveBodyMeasureUseCase(repository: healthRepo),
            fetchMeasureHistory: FetchBodyMeasureHistoryUseCase(repository: healthRepo),
            saveBodyLog: SaveBodyLogUseCase(repository: bodyLogRepo),
            fetchBodyLogs: FetchBodyLogsUseCase(repository: bodyLogRepo),
            assessRecomposition: AssessRecompositionUseCase(),
            generatePlan: GeneratePlanUseCase(),
            inferPrimary: InferPrimaryGoalUseCase(),
            describeWorkout: DescribeWorkoutUseCase(),
            suggestPlan: SuggestPlanUseCase(),
            racesViewModel: races,
            trainingViewModel: training
        )
    }

    /// Carga los tres ViewModels desde sus streams, en el orden en que lo hace la app.
    func start() async {
        await races.start()
        await training.start()
        await goals.start()
    }
}

// MARK: - Estado global que las pruebas tienen que limpiar

/// Los ViewModels guardan en `UserDefaults` la config del plan, el estado de la semana y las
/// carreras ya agregadas al calendario. En pruebas ese almacén es **compartido entre todas**: sin
/// limpiarlo, la lesión que dejó una prueba hace que la siguiente vea `weekAdherence == nil` y
/// falle por un motivo que no tiene nada que ver con ella.
///
/// Se llama al construir el `TestApp` —antes de crear los ViewModels, porque `RacesViewModel` lee
/// sus claves en el inicializador de la propiedad— y las suites que lo usan van `.serialized`.
@MainActor
func clearPersistedDefaults() {
    for key in ["plan.daysPerWeek", "plan.weekdays", "week.status", "week.status.weekStart",
                "calendarAddedKeys", "plan.frozenWeek",
                "intake.intent", "intake.hasHills", "intake.declaredWeeklyKm"] {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
