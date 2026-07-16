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

/// Trae los datos de recuperación desde Salud.
struct FetchRecoveryUseCase: Sendable {
    private let repository: HealthRepository
    init(repository: HealthRepository) { self.repository = repository }

    func callAsFunction() async throws -> RecoverySnapshot? {
        try await repository.fetchRecovery()
    }
}

/// Trae la serie de HRV y sueño para graficar la tendencia de recuperación.
struct FetchRecoveryTrendUseCase: Sendable {
    private let repository: HealthRepository
    init(repository: HealthRepository) { self.repository = repository }

    func callAsFunction(days: Int = 30) async throws -> RecoveryTrend? {
        try await repository.fetchRecoveryTrend(days: days)
    }
}

/// Estima el tiempo de recuperación a partir del HRV, la FC en reposo y la carga
/// reciente. Heurística **orientativa** y transparente, no es consejo médico.
struct AssessRecoveryUseCase: Sendable {

    func callAsFunction(_ s: RecoverySnapshot) -> RecoveryEstimate {
        // Carga acumulada → horas base de recuperación (≈ 1 h por cada 6 min entrenados,
        // acotado a 72 h). ponytail: constante calibrable; ajústala con datos reales.
        let loadHours = min(Double(s.recentLoadMinutes) / 6.0, 72)

        // HRV por debajo de tu base = recuperación más lenta; por encima = más rápida.
        var hrvFactor = 1.0
        var deviation: Double?
        if let current = s.currentHRV, let base = s.baselineHRV, base > 0 {
            let ratio = current / base
            deviation = (ratio - 1) * 100
            switch ratio {
            case 1.05...:   hrvFactor = 0.7
            case 0.90..<1.05: hrvFactor = 1.0
            case 0.80..<0.90: hrvFactor = 1.3
            default:        hrvFactor = 1.6
            }
        }

        // FC en reposo elevada (>5 lpm sobre tu base) → recuperación más lenta.
        var rhrFactor = 1.0
        if let current = s.restingHR, let base = s.baselineRestingHR, current > base + 5 {
            rhrFactor = 1.2
        }

        // Sueño: dormir poco frena la recuperación; dormir bien la acelera.
        // ponytail: umbrales ~7–9 h; calibrables por persona.
        var sleepFactor = 1.0
        if let sleep = s.lastNightSleepHours {
            switch sleep {
            case 7.5...:     sleepFactor = 0.85
            case 6.5..<7.5:  sleepFactor = 1.0
            case 5.5..<6.5:  sleepFactor = 1.2
            default:         sleepFactor = 1.4
            }
        }

        let needed = loadHours * hrvFactor * rhrFactor * sleepFactor
        let elapsed = s.hoursSinceLastWorkout ?? needed
        let remaining = max(0, Int((needed - elapsed).rounded()))

        let level: RecoveryLevel = remaining == 0 ? .recovered : (remaining <= 12 ? .partial : .fatigued)

        return RecoveryEstimate(
            level: level,
            remainingHours: remaining,
            currentHRV: s.currentHRV,
            baselineHRV: s.baselineHRV,
            hrvDeviationPct: deviation,
            sleepHours: s.lastNightSleepHours,
            note: note(level: level, deviation: deviation, snapshot: s),
            tips: tips(level: level, snapshot: s)
        )
    }

    private func note(level: RecoveryLevel, deviation: Double?, snapshot: RecoverySnapshot) -> String {
        if snapshot.currentHRV == nil {
            return "Sin datos de HRV del Apple Watch; el estimado se basa en tu carga y tu sueño. "
                + "Usa la app Salud con tu Watch para afinarlo."
        }
        let shortSleep = (snapshot.lastNightSleepHours ?? 8) < 6.5
        switch level {
        case .recovered:
            return "Tu HRV y tu carga reciente indican que tu cuerpo está listo para entrenar fuerte."
        case .partial:
            return "Vas recuperándote. Un entrenamiento suave está bien; deja lo intenso para más tarde."
        case .fatigued:
            let low = (deviation ?? 0) < -10 ? " Tu HRV está por debajo de tu base." : ""
            let sleep = shortSleep ? " Dormiste poco anoche, lo que frena tu recuperación." : ""
            return "Acumulaste carga y aún no te recuperas del todo.\(low)\(sleep) Prioriza descanso, sueño e hidratación."
        }
    }

    private func tips(level: RecoveryLevel, snapshot: RecoverySnapshot) -> [String] {
        var result: [String]
        switch level {
        case .recovered:
            result = ["Buen momento para una sesión de calidad (intervalos o tirada larga).",
                      "Mantén el sueño y la hidratación para sostener tu HRV."]
        case .partial:
            result = ["Haz zona 2 fácil o movilidad hoy.",
                      "Revisa de nuevo en unas horas antes de decidir un entrenamiento fuerte."]
        case .fatigued:
            result = ["Descansa o haz recuperación activa muy suave.",
                      "Hidrátate y cuida la nutrición post-entrenamiento."]
        }
        if let sleep = snapshot.lastNightSleepHours, sleep < 7 {
            result.append("Anoche dormiste \(sleep.formatted(.number.precision(.fractionLength(1)))) h; "
                + "apunta a 7–9 h: el sueño es donde más sube tu HRV.")
        }
        return result
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

/// Trae la traza GPS (+ FC) de una corrida de Salud para dibujar su ruta.
struct FetchWorkoutRouteUseCase: Sendable {
    private let repository: HealthRepository
    init(repository: HealthRepository) { self.repository = repository }

    var isAvailable: Bool { repository.isAvailable() }

    func callAsFunction(onDay date: Date, distanceKm: Double?) async throws -> WorkoutRoute? {
        try await repository.fetchRoute(onDay: date, distanceKm: distanceKm)
    }
}

/// Trae los minutos agudos/crónicos de entrenamiento desde Salud.
struct FetchWorkloadUseCase: Sendable {
    private let repository: HealthRepository
    init(repository: HealthRepository) { self.repository = repository }

    func callAsFunction() async throws -> WorkloadInput? {
        try await repository.fetchWorkload()
    }
}

/// Calcula la relación carga aguda:crónica (ACWR) y su zona. `nil` si aún no hay base
/// de 4 semanas para comparar.
struct AssessWorkloadUseCase: Sendable {

    func callAsFunction(_ input: WorkloadInput) -> WorkloadRatio? {
        let weeklyAverage = Double(input.chronicMinutes) / 4.0
        guard weeklyAverage > 0 else { return nil }   // sin base todavía

        let ratio = Double(input.acuteMinutes) / weeklyAverage
        let zone: WorkloadZone
        switch ratio {
        case ..<0.8:      zone = .detraining
        case 0.8..<1.3:   zone = .optimal
        case 1.3..<1.5:   zone = .caution
        default:          zone = .highRisk
        }

        return WorkloadRatio(
            acuteMinutes: input.acuteMinutes,
            weeklyAverageMinutes: Int(weeklyAverage.rounded()),
            ratio: ratio,
            zone: zone,
            note: note(for: zone)
        )
    }

    private func note(for zone: WorkloadZone) -> String {
        switch zone {
        case .detraining:
            return "Tu carga de esta semana está por debajo de tu promedio. Bien para recuperar; si "
                + "buscas progresar, retómala de forma gradual (~10% por semana)."
        case .optimal:
            return "Vas en la zona dulce: progresas con bajo riesgo. Mantén los aumentos alrededor de "
                + "10% por semana."
        case .caution:
            return "Subiste la carga rápido. Vigila señales de fatiga y evita aumentar más esta semana."
        case .highRisk:
            return "Tu carga esta semana es bastante mayor que tu promedio, lo que dispara el riesgo de "
                + "lesión. Considera bajar el volumen o intercalar días fáciles."
        }
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
