import Foundation
import Observation

@MainActor
@Observable
final class HealthViewModel {

    enum State: Equatable {
        case unavailable          // p. ej. en Mac
        case needsAuthorization
        case loading
        case loaded(FitnessSummary, [RaceReadiness])
        case error(String)
    }

    private(set) var state: State

    private let fetchSummary: FetchFitnessSummaryUseCase
    private let assessReadiness: AssessReadinessUseCase

    init(fetchSummary: FetchFitnessSummaryUseCase, assessReadiness: AssessReadinessUseCase) {
        self.fetchSummary = fetchSummary
        self.assessReadiness = assessReadiness
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

    /// Recarga el resumen (asume autorización ya solicitada).
    func load() async {
        guard fetchSummary.isAvailable else { state = .unavailable; return }
        state = .loading
        do {
            let summary = try await fetchSummary()
            state = .loaded(summary, assessReadiness(summary))
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
