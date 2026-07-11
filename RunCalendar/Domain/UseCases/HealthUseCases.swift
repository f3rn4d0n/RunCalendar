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

    /// Aviso de que Salud tiene datos nuevos (para refrescar sin recargar de más).
    func updates() -> AsyncStream<Void> {
        repository.workoutUpdates()
    }
}

/// Trae las carreras recientes de Salud para sugerir importarlas.
struct FetchRecentWorkoutsUseCase: Sendable {
    private let repository: HealthRepository
    init(repository: HealthRepository) { self.repository = repository }

    var isAvailable: Bool { repository.isAvailable() }

    func callAsFunction(days: Int = 14) async throws -> [HealthWorkout] {
        try await repository.fetchRecentWorkouts(days: days)
    }

    /// Aviso de que Salud tiene entrenamientos nuevos (para re-sincronizar).
    func updates() -> AsyncStream<Void> {
        repository.workoutUpdates()
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
                currentLongRunKm: summary.longestRunKm,
                recommendedLongRunKm: target.longRunKm,
                currentWeeklyKm: summary.weeklyDistanceKm,
                recommendedWeeklyKm: target.weeklyMinKm,
                note: note(for: target, level: level, summary: summary),
                recommendations: recommendations(for: target, summary: summary)
            )
        }
    }

    /// El nivel se decide por la carrera más larga vs. el long run recomendado.
    /// El volumen semanal no es un candado: se sugiere en la nota.
    private func level(for target: Target, summary: FitnessSummary) -> ReadinessLevel {
        let longest = summary.longestRunKm
        if longest >= target.longRunKm { return .ready }
        if longest >= target.longRunKm * 0.7 { return .almost }
        return .building
    }

    private func note(for target: Target, level: ReadinessLevel, summary: FitnessSummary) -> String {
        let longest = summary.longestRunKm.formatted(.number.precision(.fractionLength(0)))
        switch level {
        case .ready:
            var text = "Tu carrera más larga (\(longest) km) cubre esta distancia."
            if summary.weeklyDistanceKm < target.weeklyMinKm {
                text += " Para más comodidad, sube tu volumen hacia \(Int(target.weeklyMinKm)) km/semana."
            }
            return text
        case .almost:
            return "Casi. Sube tu long run hacia \(Int(target.longRunKm)) km."
        case .building:
            return "Construye base: apunta a \(Int(target.longRunKm)) km de long run y "
                + "\(Int(target.weeklyMinKm)) km semanales."
        }
    }

    /// Recomendaciones concretas de qué mejorar para llegar listo a la distancia.
    private func recommendations(for target: Target, summary: FitnessSummary) -> [String] {
        var recs: [String] = []
        if summary.longestRunKm < target.longRunKm {
            let gap = target.longRunKm - summary.longestRunKm
            recs.append("Sube tu carrera más larga de \(fmt(summary.longestRunKm)) a "
                + "\(Int(target.longRunKm)) km (≈ +\(fmt(gap)) km), sumando 1–2 km por semana.")
        }
        if summary.weeklyDistanceKm < target.weeklyMinKm {
            recs.append("Aumenta tu volumen semanal de \(fmt(summary.weeklyDistanceKm)) a "
                + "\(Int(target.weeklyMinKm)) km, sin subir más de ~10% por semana.")
        }
        recs.append(contentsOf: focusTips(for: target.distance))
        if summary.longestRunKm >= target.longRunKm && summary.weeklyDistanceKm >= target.weeklyMinKm {
            recs.insert("¡Vas listo! Mantén tu rutina y llega descansado al evento.", at: 0)
        }
        return recs
    }

    private func focusTips(for distance: RaceDiscipline) -> [String] {
        switch distance {
        case .fiveK, .tenK:
            return [
                "Corre la mayoría de tus kilómetros en zona 2 (fácil, puedes conversar).",
                "Agrega 1 sesión semanal de intervalos/sprints para ganar velocidad."
            ]
        case .halfMarathon, .marathon:
            return [
                "Prioriza la tirada larga semanal en zona 2 para construir resistencia.",
                "Practica tu nutrición e hidratación en las tiradas largas.",
                "Incluye 1 día de ritmo objetivo de carrera cada semana."
            ]
        default:
            return ["Mantén una base de carrera fácil (zona 2) constante."]
        }
    }

    private func fmt(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
