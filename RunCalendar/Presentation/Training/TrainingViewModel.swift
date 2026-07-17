import Foundation
import Observation

@MainActor
@Observable
final class TrainingViewModel {

    private(set) var sessions: [TrainingSession] = []
    private(set) var recentWorkouts: [HealthWorkout] = []
    var errorMessage: String?
    private var hasStarted = false
    private var sessionsLoaded = false
    private var isSyncing = false
    /// IDs ya importados esta sesión: evita duplicar si Salud avisa antes de
    /// que Firestore refleje los recién guardados.
    private var importedIDs: Set<String> = []

    let userID: String
    private let observeTrainings: ObserveTrainingsUseCase
    private let addTraining: AddTrainingUseCase
    private let updateTraining: UpdateTrainingUseCase
    private let deleteTraining: DeleteTrainingUseCase
    private let fetchRecentWorkouts: FetchRecentWorkoutsUseCase
    private let fetchWorkoutRoute: FetchWorkoutRouteUseCase
    private let fetchWeather: FetchRaceWeatherUseCase

    init(
        userID: String,
        observeTrainings: ObserveTrainingsUseCase,
        addTraining: AddTrainingUseCase,
        updateTraining: UpdateTrainingUseCase,
        deleteTraining: DeleteTrainingUseCase,
        fetchRecentWorkouts: FetchRecentWorkoutsUseCase,
        fetchWorkoutRoute: FetchWorkoutRouteUseCase,
        fetchWeather: FetchRaceWeatherUseCase
    ) {
        self.userID = userID
        self.observeTrainings = observeTrainings
        self.addTraining = addTraining
        self.updateTraining = updateTraining
        self.deleteTraining = deleteTraining
        self.fetchRecentWorkouts = fetchRecentWorkouts
        self.fetchWorkoutRoute = fetchWorkoutRoute
        self.fetchWeather = fetchWeather
    }

    /// Clima del entrenamiento: usa las coordenadas de la traza GPS de Salud (sin pedir
    /// dirección ni geocodificar). `nil` si no es carrera o no tiene ruta con GPS.
    // ponytail: reusa route() (trae toda la traza + FC); si pesa, un query de solo
    // la primera coordenada del workout sería más ligero.
    func weather(for session: TrainingSession) async -> RaceWeather? {
        guard session.type == .running,
              let start = await route(onDay: session.date, distanceKm: session.distanceKm)?.points.first
        else { return nil }
        do {
            return try await fetchWeather(latitude: start.latitude, longitude: start.longitude, date: session.date)
        } catch {
            Log.health.error("weather(training): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// ¿El dispositivo puede leer rutas de Salud? (falso en Mac).
    var canShowRoutes: Bool { fetchWorkoutRoute.isAvailable }

    /// Traza GPS de la corrida de Salud de ese día (para el detalle de carrera/entrenamiento).
    func route(onDay date: Date, distanceKm: Double?) async -> WorkoutRoute? {
        do {
            return try await fetchWorkoutRoute(onDay: date, distanceKm: distanceKm)
        } catch {
            Log.health.error("route: error al leer ruta: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func sessions(of type: TrainingType) -> [TrainingSession] {
        sessions.filter { $0.type == type }
    }

    /// Carreras de Salud que aún no tienen un entrenamiento parecido registrado.
    var importableWorkouts: [HealthWorkout] {
        recentWorkouts.filter { workout in
            !importedIDs.contains(workout.id)
                && !sessions.contains { isSameActivity(day: workout.date, km: workout.distanceKm, with: $0) }
        }
    }

    /// Sincroniza con Salud: carga todas las carreras e importa las que falten.
    /// Silencioso: en Mac o sin permiso no hace nada. Espera al primer snapshot
    /// de Firestore para no importar duplicados de lo ya registrado.
    func syncFromHealth() async {
        guard sessionsLoaded, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        recentWorkouts = (try? await fetchRecentWorkouts(days: 0)) ?? []
        for workout in importableWorkouts {
            importedIDs.insert(workout.id)
            await importWorkout(workout)
        }
    }

    /// Re-sincroniza cuando Salud reporta entrenamientos nuevos. Llamar una vez por sesión.
    func observeHealthUpdates() async {
        for await _ in fetchRecentWorkouts.updates() {
            await syncFromHealth()
        }
    }

    /// Importa una carrera de Salud como entrenamiento completado.
    func importWorkout(_ workout: HealthWorkout) async {
        let km = workout.distanceKm.formatted(.number.precision(.fractionLength(1)))
        let session = TrainingSession(
            date: workout.date,
            type: .running,
            title: "Carrera \(km) km",
            durationMin: workout.durationMin,
            distanceKm: workout.distanceKm,
            avgHeartRate: workout.avgHeartRate,
            completed: true
        )
        _ = await save(session, isNew: true)
    }

    /// Entrenamiento existente parecido a uno nuevo (mismo día, carrera, distancia similar).
    func similarSession(to candidate: TrainingSession) -> TrainingSession? {
        guard candidate.type == .running else { return nil }
        return sessions.first {
            $0.id != candidate.id
                && isSameActivity(day: candidate.date, km: candidate.distanceKm, with: $0)
        }
    }

    // ponytail: dedup por (día + distancia ~10%); si dos carreras iguales el mismo día
    // colisionan de más, guardar el UUID de HealthKit en TrainingSession.
    private func isSameActivity(day: Date, km: Double?, with session: TrainingSession) -> Bool {
        guard session.type == .running, let new = km, let existing = session.distanceKm else { return false }
        return Calendar.current.isDate(day, inSameDayAs: session.date)
            && abs(new - existing) <= max(0.5, new * 0.1)
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        for await items in observeTrainings(userID: userID) {
            sessions = items
            if !sessionsLoaded {
                sessionsLoaded = true
                Task { await self.syncFromHealth() } // primer snapshot listo: sincronizar
            }
        }
    }

    func save(_ session: TrainingSession, isNew: Bool) async -> Bool {
        do {
            if isNew {
                try await addTraining(session, userID: userID)
            } else {
                try await updateTraining(session, userID: userID)
            }
            Haptics.success()
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
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
