import Foundation

/// Obtiene el resumen de condición física desde Salud.
struct FetchFitnessSummaryUseCase: Sendable {
    private let repository: HealthRepository
    init(repository: HealthRepository) { self.repository = repository }

    var isAvailable: Bool { repository.isAvailable() }

    func requestAuthorization() async -> Bool {
        await repository.requestAuthorization()
    }

    func callAsFunction(weeks: Int = 8) async throws -> FitnessSummary {
        try await repository.fetchSummary(weeks: weeks)
    }
}

/// Estima la preparación para las distancias clásicas a partir del resumen.
/// Heurística orientativa (long run objetivo + volumen semanal), no consejo médico.
struct AssessReadinessUseCase: Sendable {

    private struct Target {
        let distance: RaceDiscipline
        let longRunKm: Double
        let weeklyMinKm: Double
    }

    private let targets: [Target] = [
        Target(distance: .fiveK, longRunKm: 5, weeklyMinKm: 15),
        Target(distance: .tenK, longRunKm: 10, weeklyMinKm: 20),
        Target(distance: .halfMarathon, longRunKm: 18, weeklyMinKm: 30),
        Target(distance: .marathon, longRunKm: 32, weeklyMinKm: 50)
    ]

    func callAsFunction(_ summary: FitnessSummary) -> [RaceReadiness] {
        targets.map { target in
            let level = level(for: target, summary: summary)
            return RaceReadiness(
                distance: target.distance,
                level: level,
                recommendedLongRunKm: target.longRunKm,
                note: note(for: target, level: level, summary: summary)
            )
        }
    }

    private func level(for target: Target, summary: FitnessSummary) -> ReadinessLevel {
        let hasLongRun = summary.longestRunKm >= target.longRunKm
        let hasVolume = summary.weeklyDistanceKm >= target.weeklyMinKm
        if hasLongRun && hasVolume { return .ready }
        if summary.longestRunKm >= target.longRunKm * 0.7 { return .almost }
        return .building
    }

    private func note(for target: Target, level: ReadinessLevel, summary: FitnessSummary) -> String {
        let longest = summary.longestRunKm
        switch level {
        case .ready:
            return "Tu base te alcanza: llegas a \(longest.formatted(.number.precision(.fractionLength(0)))) km."
        case .almost:
            return "Vas bien. Sube tu long run hacia \(Int(target.longRunKm)) km y mantén el volumen."
        case .building:
            return "Construye base: apunta a \(Int(target.longRunKm)) km de long run y "
                + "\(Int(target.weeklyMinKm)) km semanales."
        }
    }
}
