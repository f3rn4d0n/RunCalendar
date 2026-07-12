import Foundation

/// Contrato de acceso a datos de salud. Implementado con HealthKit en la capa Data.
protocol HealthRepository: Sendable {
    /// Si el dispositivo tiene datos de salud disponibles (falso en Mac).
    func isAvailable() -> Bool

    /// Pide autorización de lectura al usuario. Devuelve si el usuario respondió
    /// (no si concedió cada tipo: HealthKit no revela qué se concedió por privacidad).
    func requestAuthorization() async -> Bool

    /// Calcula el resumen de condición de las últimas `weeks` semanas.
    func fetchSummary(weeks: Int) async throws -> FitnessSummary

    /// Carreras registradas en Salud en los últimos `days` días (para importarlas).
    func fetchRecentWorkouts(days: Int) async throws -> [HealthWorkout]

    /// Emite un aviso cuando cambian los entrenamientos en Salud
    /// (y una vez al empezar a observar). Vacío donde no hay HealthKit.
    func workoutUpdates() -> AsyncStream<Void>
}
