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
    /// Check-ins recientes (cronológicos) para la gráfica "sentido vs predicho".
    private(set) var recentCheckIns: [RecoveryCheckIn] = []

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
            // Check-ins primero: alimentan la calibración de la recuperación.
            await loadTodayCheckIn()
            let calibration = RecoveryCalibration(checkIns: recentCheckIns)
            let recovery = try await fetchRecovery().map { assessRecovery($0, calibration: calibration) }
            let recoveryTrend = (try? await fetchRecoveryTrend()) ?? nil
            let workload = try await fetchWorkload().flatMap(assessWorkload.callAsFunction)
            let fitnessTrend = (try? await fetchFitnessTrend()) ?? nil
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
        recentCheckIns = recent
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
            recentCheckIns.removeAll { Calendar.current.isDate($0.date, inSameDayAs: checkIn.date) }
            recentCheckIns.append(checkIn)
            Haptics.success()
        } catch {
            Log.health.error("submitCheckIn: \(error.localizedDescription, privacy: .public)")
        }
    }

#if DEBUG
    /// Debug: siembra check-ins sintéticos en memoria (sesgo positivo: te sentiste mejor de
    /// lo previsto) para ver la calibración sin esperar días. No toca Firestore; al reiniciar
    /// la app se pierde y vuelven los datos reales.
    func seedDemoCheckIns() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        recentCheckIns = (1...18).reversed().map { day in
            RecoveryCheckIn(
                date: cal.date(byAdding: .day, value: -day, to: today) ?? today,
                feeling: 5,                    // te sentiste fresco…
                predictedRemainingHours: 30,   // …pero el modelo pedía ~1 día (modelFeeling 2)
                hrv: nil, baselineHRV: nil, sleepHours: nil
            )
        }
        let calibration = RecoveryCalibration(checkIns: recentCheckIns)
        guard case .loaded(let data) = state else { return }
        let snapshot = (try? await fetchRecovery()) ?? nil
        let recovery = snapshot.map { assessRecovery($0, calibration: calibration) } ?? data.recovery
        state = .loaded(HealthLoaded(
            summary: data.summary,
            readiness: data.readiness,
            recovery: recovery,
            recoveryTrend: data.recoveryTrend,
            workload: data.workload,
            fitnessTrend: data.fitnessTrend
        ))
    }
#endif
}
