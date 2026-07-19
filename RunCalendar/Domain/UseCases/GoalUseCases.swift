import Foundation

/// Stream de las metas del usuario.
struct ObserveGoalsUseCase: Sendable {
    private let repository: GoalRepository
    init(repository: GoalRepository) { self.repository = repository }
    func callAsFunction(userID: String) -> AsyncStream<[Goal]> {
        repository.goalsStream(userID: userID)
    }
}

struct AddGoalUseCase: Sendable {
    private let repository: GoalRepository
    init(repository: GoalRepository) { self.repository = repository }
    func callAsFunction(_ goal: Goal, userID: String) async throws {
        try await repository.add(goal, userID: userID)
    }
}

struct UpdateGoalUseCase: Sendable {
    private let repository: GoalRepository
    init(repository: GoalRepository) { self.repository = repository }
    func callAsFunction(_ goal: Goal, userID: String) async throws {
        try await repository.update(goal, userID: userID)
    }
}

struct DeleteGoalUseCase: Sendable {
    private let repository: GoalRepository
    init(repository: GoalRepository) { self.repository = repository }
    func callAsFunction(goalID: String, userID: String) async throws {
        try await repository.delete(goalID: goalID, userID: userID)
    }
}

/// Sugiere una meta realista con fórmulas deportivas estándar (sin IA), como punto de partida.
/// - Tiempo: fórmula de Riegel desde tu mejor PR (equivalente en otra distancia, o −3% en la misma).
/// - VO₂max: tu actual + una mejora realista de bloque (~3 puntos).
/// - Peso: hacia IMC saludable (~23) con tu estatura, acotado a ~8% de baja; sin estatura, −5%.
struct RecommendGoalUseCase: Sendable {
    func callAsFunction(
        type: GoalType, distance: RaceDiscipline?,
        records: [PersonalRecord], metrics: AthleteMetrics?, now: Date = Date()
    ) -> GoalRecommendation? {
        switch type {
        case .raceTime: return raceTime(distance: distance, records: records, now: now)
        case .vo2max:   return vo2max(metrics: metrics, now: now)
        case .weight:   return weight(metrics: metrics, now: now)
        }
    }

    private func raceTime(distance: RaceDiscipline?, records: [PersonalRecord], now: Date) -> GoalRecommendation? {
        guard let distance, let targetKm = distance.standardDistanceKm, !records.isEmpty else { return nil }
        // Base: un PR de otra distancia (predicción Riegel) o el de la misma (mejora del 3%).
        let base = records.first { $0.distance != distance } ?? records.first
        guard let base, let baseKm = base.distance.standardDistanceKm else { return nil }
        let predicted = Double(base.best.timeSeconds) * pow(targetKm / baseKm, 1.06)
        let target = base.distance == distance ? predicted * 0.97 : predicted
        return GoalRecommendation(
            targetValue: target.rounded(),
            deadline: weeksFromNow(12, now),   // bloque de entrenamiento estándar
            rationale: "Basado en tu PR de \(base.distance.displayName) "
                + "(\(Goal.formatTime(base.best.timeSeconds))). Bloque de ~12 semanas."
        )
    }

    private func vo2max(metrics: AthleteMetrics?, now: Date) -> GoalRecommendation? {
        guard let current = metrics?.vo2max else { return nil }
        let target = (current + 3).rounded()
        return GoalRecommendation(
            targetValue: target,
            deadline: weeksFromNow(12, now),
            rationale: "De \(Goal.trim(current)) a \(Goal.trim(target)): +3 en ~12 semanas es realista."
        )
    }

    private func weight(metrics: AthleteMetrics?, now: Date) -> GoalRecommendation? {
        guard let current = metrics?.weightKg else { return nil }
        let target: Double
        let note: String
        if let h = metrics?.heightM, h > 0 {
            let bmi = current / (h * h)
            guard bmi > 24.9 else {
                return GoalRecommendation(targetValue: current.rounded(), deadline: weeksFromNow(8, now),
                                          rationale: "Tu IMC ya está en rango saludable; enfócate en mantener.")
            }
            let healthy = 23.0 * h * h        // objetivo IMC 23 (medio del rango saludable)
            let safeFloor = current * 0.92    // no más de ~8% de baja por meta (seguro)
            target = max(healthy, safeFloor).rounded()
            note = "Hacia un IMC saludable (~23), sin pasar de ~8% de baja"
        } else {
            target = (current * 0.95).rounded()
            note = "Baja conservadora (~5%); agrega tu estatura en Salud para una meta por IMC"
        }
        // Plazo a un ritmo seguro de ~0.5 kg/semana (mín. 4 semanas).
        let weeks = max(4, Int(((current - target) / 0.5).rounded(.up)))
        return GoalRecommendation(targetValue: target, deadline: weeksFromNow(weeks, now),
                                  rationale: "\(note) (~\(weeks) sem a 0.5 kg/sem).")
    }

    /// Fecha `weeks` semanas después de `now`.
    private func weeksFromNow(_ weeks: Int, _ now: Date) -> Date? {
        Calendar.current.date(byAdding: .day, value: weeks * 7, to: now)
    }
}

/// Confianza cualitativa (Alta/Media/Baja) de lograr una meta, con heurísticas defendibles —
/// nunca un % inventado. Tiempo: qué tan exigente es el objetivo vs. lo que Riegel predice desde
/// tu PR. Peso/VO₂max: si el ritmo de cambio necesario hasta la fecha es realista. `nil` = sin datos.
struct AssessGoalConfidenceUseCase: Sendable {
    func callAsFunction(_ goal: Goal, current: Double?, records: [PersonalRecord], now: Date = Date()) -> GoalConfidence? {
        if let current, (goal.type.higherIsBetter ? current >= goal.targetValue : current <= goal.targetValue) {
            return .achieved
        }
        switch goal.type {
        case .raceTime: return raceConfidence(goal, records: records)
        case .vo2max:   return rateConfidence(current: current, target: goal.targetValue, deadline: goal.deadline,
                                              now: now, higherBetter: true, easy: 0.3, mid: 0.55)  // puntos/semana
        case .weight:   return rateConfidence(current: current, target: goal.targetValue, deadline: goal.deadline,
                                              now: now, higherBetter: false, easy: 0.5, mid: 0.75) // kg/semana
        }
    }

    /// Compara el objetivo con el tiempo que Riegel predice desde tu mejor PR.
    private func raceConfidence(_ goal: Goal, records: [PersonalRecord]) -> GoalConfidence? {
        guard let distance = goal.distance, let targetKm = distance.standardDistanceKm,
              let base = (records.first { $0.distance != distance } ?? records.first),
              let baseKm = base.distance.standardDistanceKm else { return nil }
        let predicted = Double(base.best.timeSeconds) * pow(targetKm / baseKm, 1.06)
        let ratio = goal.targetValue / predicted   // >1 = objetivo más lento (más fácil) que tu nivel
        switch ratio {
        case 0.99...:      return .high
        case 0.95..<0.99:  return .medium
        default:           return .low
        }
    }

    /// ¿Es realista el ritmo de cambio necesario hasta la fecha?
    private func rateConfidence(current: Double?, target: Double, deadline: Date?, now: Date,
                                higherBetter: Bool, easy: Double, mid: Double) -> GoalConfidence? {
        guard let current, let deadline else { return nil }
        let weeks = max(1, deadline.timeIntervalSince(now) / (7 * 86400))
        let change = higherBetter ? (target - current) : (current - target)
        guard change > 0 else { return .high }
        let perWeek = change / weeks
        switch perWeek {
        case ..<easy:      return .high
        case easy..<mid:   return .medium
        default:           return .low
        }
    }
}

/// Calcula el progreso de una meta contra su valor actual (`current`), agnóstico de la fuente.
/// `current` nil = aún no hay dato (p. ej. sin PR para esa distancia, o métrica no cableada).
struct AssessGoalProgressUseCase: Sendable {
    func callAsFunction(_ goal: Goal, current: Double?) -> GoalProgress {
        guard let current else {
            return GoalProgress(achieved: false, fraction: nil,
                                currentText: "—", deltaText: "Registra el dato")
        }
        let achieved = goal.type.higherIsBetter ? current >= goal.targetValue : current <= goal.targetValue
        let currentText = Goal.format(current, type: goal.type)

        let deltaText: String
        if achieved {
            deltaText = "¡Logrado!"
        } else {
            let gap = abs(current - goal.targetValue)
            deltaText = "faltan \(Goal.format(gap, type: goal.type))"
        }

        var fraction: Double?
        if let start = goal.startValue, start != goal.targetValue {
            let raw = goal.type.higherIsBetter
                ? (current - start) / (goal.targetValue - start)
                : (start - current) / (start - goal.targetValue)
            fraction = min(max(raw, 0), 1)
        }

        return GoalProgress(achieved: achieved, fraction: fraction,
                            currentText: currentText, deltaText: deltaText)
    }
}
