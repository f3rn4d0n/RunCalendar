import Foundation
import Observation

/// Todo lo que se muestra en Condición cuando hay datos cargados.
struct HealthLoaded: Equatable {
    let summary: FitnessSummary
    let readiness: [RaceReadiness]
    let recovery: RecoveryEstimate?
    let recoveryTrend: RecoveryTrend?
    let workload: WorkloadRatio?
    let fitnessTrend: FitnessTrend?
}

@MainActor
@Observable
final class HealthViewModel {

    enum State: Equatable {
        case unavailable          // p. ej. en Mac
        case needsAuthorization
        case loading
        case loaded(HealthLoaded)
        case error(String)
    }

    private(set) var state: State

    /// Readiness por distancia si ya se cargó (para el detalle de carrera). Vacío si no.
    var readinessByDistance: [RaceReadiness] {
        if case .loaded(let data) = state { return data.readiness }
        return []
    }

    /// ¿Hay datos de salud disponibles en este dispositivo? (falso en Mac).
    var isHealthAvailable: Bool { fetchSummary.isAvailable }

    /// Check-in de recuperación de hoy, si ya se registró.
    private(set) var todayCheckIn: RecoveryCheckIn?

    private let userID: String
    private let fetchSummary: FetchFitnessSummaryUseCase
    private let assessReadiness: AssessReadinessUseCase
    private let fetchRecovery: FetchRecoveryUseCase
    private let assessRecovery: AssessRecoveryUseCase
    private let fetchRecoveryTrend: FetchRecoveryTrendUseCase
    private let fetchWorkload: FetchWorkloadUseCase
    private let assessWorkload: AssessWorkloadUseCase
    private let fetchFitnessTrend: FetchFitnessTrendUseCase
    private let saveCheckIn: SaveRecoveryCheckInUseCase
    private let fetchCheckIns: FetchRecoveryCheckInsUseCase

    init(
        userID: String,
        fetchSummary: FetchFitnessSummaryUseCase,
        assessReadiness: AssessReadinessUseCase,
        fetchRecovery: FetchRecoveryUseCase,
        assessRecovery: AssessRecoveryUseCase,
        fetchRecoveryTrend: FetchRecoveryTrendUseCase,
        fetchWorkload: FetchWorkloadUseCase,
        assessWorkload: AssessWorkloadUseCase,
        fetchFitnessTrend: FetchFitnessTrendUseCase,
        saveCheckIn: SaveRecoveryCheckInUseCase,
        fetchCheckIns: FetchRecoveryCheckInsUseCase
    ) {
        self.userID = userID
        self.fetchSummary = fetchSummary
        self.assessReadiness = assessReadiness
        self.fetchRecovery = fetchRecovery
        self.assessRecovery = assessRecovery
        self.fetchRecoveryTrend = fetchRecoveryTrend
        self.fetchWorkload = fetchWorkload
        self.assessWorkload = assessWorkload
        self.fetchFitnessTrend = fetchFitnessTrend
        self.saveCheckIn = saveCheckIn
        self.fetchCheckIns = fetchCheckIns
        // Arranca cargando (no en "conectar"): HealthKit no re-muestra la hoja de
        // permisos si el usuario ya respondió, así que cargamos directo.
        self.state = fetchSummary.isAvailable ? .loading : .unavailable
    }

    /// Al aparecer: solicita (sin re-mostrar la hoja si ya se respondió) y carga.
    func onAppear() async {
        guard fetchSummary.isAvailable else { state = .unavailable; return }
        if case .loaded = state { return } // ya cargado, no recargar
        await connect()
    }

    /// Pide autorización y carga el resumen.
    func connect() async {
        guard fetchSummary.isAvailable else { state = .unavailable; return }
        state = .loading
        let granted = await fetchSummary.requestAuthorization()
        guard granted else {
            state = .error("No se pudo acceder a Salud. Revisa los permisos en Ajustes.")
            return
        }
        await load()
    }

    /// Refresca cuando Salud reporta cambios. Llamar una vez por sesión;
    /// solo actúa si ya hay datos cargados (la carga inicial la hace onAppear).
    func observeUpdates() async {
        for await _ in fetchSummary.updates() {
            if case .loaded = state { await load() }
        }
    }

    /// Recarga el resumen (asume autorización ya solicitada).
    func load() async {
        guard fetchSummary.isAvailable else { state = .unavailable; return }
        // Refresco silencioso: si ya hay datos no volvemos al spinner.
        if case .loaded = state {} else { state = .loading }
        do {
            let summary = try await fetchSummary()
            let recovery = try await fetchRecovery().map(assessRecovery.callAsFunction)
            let recoveryTrend = (try? await fetchRecoveryTrend()) ?? nil
            let workload = try await fetchWorkload().flatMap(assessWorkload.callAsFunction)
            let fitnessTrend = (try? await fetchFitnessTrend()) ?? nil
            await loadTodayCheckIn()
            state = .loaded(HealthLoaded(
                summary: summary,
                readiness: assessReadiness(summary),
                recovery: recovery,
                recoveryTrend: recoveryTrend,
                workload: workload,
                fitnessTrend: fitnessTrend
            ))
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func loadTodayCheckIn() async {
        let recent = (try? await fetchCheckIns(userID: userID)) ?? []
        let today = Calendar.current.startOfDay(for: Date())
        todayCheckIn = recent.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    /// Guarda cómo te sientes hoy (1–5), junto con lo que el modelo predijo, para calibrar.
    func submitCheckIn(feeling: Int) async {
        let recovery: RecoveryEstimate?
        if case .loaded(let data) = state { recovery = data.recovery } else { recovery = nil }
        let checkIn = RecoveryCheckIn(
            date: Calendar.current.startOfDay(for: Date()),
            feeling: feeling,
            predictedRemainingHours: recovery?.remainingHours ?? 0,
            hrv: recovery?.currentHRV,
            baselineHRV: recovery?.baselineHRV,
            sleepHours: recovery?.sleepHours
        )
        do {
            try await saveCheckIn(checkIn, userID: userID)
            todayCheckIn = checkIn
            Haptics.success()
        } catch {
            Log.health.error("submitCheckIn: \(error.localizedDescription, privacy: .public)")
        }
    }
}
