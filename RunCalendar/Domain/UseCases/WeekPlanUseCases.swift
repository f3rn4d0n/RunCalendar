import Foundation

/// Guarda la semana ya decidida, para que siga existiendo cuando pase.
struct SaveWeekPlanUseCase: Sendable {
    let repository: WeekPlanRepository
    func callAsFunction(_ week: FrozenWeek, userID: String) async throws {
        try await repository.save(week, userID: userID)
    }
}

/// La semana decidida que empieza en `weekStart`, si la hay.
struct FetchWeekPlanUseCase: Sendable {
    let repository: WeekPlanRepository
    func callAsFunction(weekStart: Date, userID: String) async throws -> FrozenWeek? {
        try await repository.fetch(weekStart: weekStart, userID: userID)
    }
}

/// Las últimas semanas guardadas: lo que hace posible mirar atrás.
struct FetchRecentWeekPlansUseCase: Sendable {
    let repository: WeekPlanRepository
    func callAsFunction(weeks: Int, userID: String) async throws -> [FrozenWeek] {
        try await repository.recent(weeks: weeks, userID: userID)
    }
}
