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
        self.state = fetchSummary.isAvailable ? .needsAuthorization : .unavailable
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
