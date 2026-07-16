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

    private let fetchSummary: FetchFitnessSummaryUseCase
    private let assessReadiness: AssessReadinessUseCase
    private let fetchRecovery: FetchRecoveryUseCase
    private let assessRecovery: AssessRecoveryUseCase
    private let fetchRecoveryTrend: FetchRecoveryTrendUseCase
    private let fetchWorkload: FetchWorkloadUseCase
    private let assessWorkload: AssessWorkloadUseCase
    private let fetchFitnessTrend: FetchFitnessTrendUseCase

    init(
        fetchSummary: FetchFitnessSummaryUseCase,
        assessReadiness: AssessReadinessUseCase,
        fetchRecovery: FetchRecoveryUseCase,
        assessRecovery: AssessRecoveryUseCase,
        fetchRecoveryTrend: FetchRecoveryTrendUseCase,
        fetchWorkload: FetchWorkloadUseCase,
        assessWorkload: AssessWorkloadUseCase,
        fetchFitnessTrend: FetchFitnessTrendUseCase
    ) {
        self.fetchSummary = fetchSummary
        self.assessReadiness = assessReadiness
        self.fetchRecovery = fetchRecovery
        self.assessRecovery = assessRecovery
        self.fetchRecoveryTrend = fetchRecoveryTrend
        self.fetchWorkload = fetchWorkload
        self.assessWorkload = assessWorkload
        self.fetchFitnessTrend = fetchFitnessTrend
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
}
