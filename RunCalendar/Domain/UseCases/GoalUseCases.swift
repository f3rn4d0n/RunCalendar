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
