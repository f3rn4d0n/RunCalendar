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

    /// Datos crudos (HRV, FC en reposo, carga reciente) para estimar recuperación.
    func fetchRecovery() async throws -> RecoverySnapshot?

    /// Serie diaria de HRV y sueño de los últimos `days` días (para graficar la tendencia).
    func fetchRecoveryTrend(days: Int) async throws -> RecoveryTrend?

    /// Minutos de entrenamiento agudos (7 d) y crónicos (28 d) para la relación ACWR.
    func fetchWorkload() async throws -> WorkloadInput?

    /// Volumen semanal y ritmo por corrida de las últimas `weeks` semanas (para graficar).
    func fetchFitnessTrend(weeks: Int) async throws -> FitnessTrend?

    /// Carreras registradas en Salud en los últimos `days` días (para importarlas).
    func fetchRecentWorkouts(days: Int) async throws -> [HealthWorkout]

    /// Traza GPS (+ FC por punto) de la corrida de Salud de ese día que mejor
    /// coincide con `distanceKm`. `nil` si no hay corrida con ruta ese día.
    func fetchRoute(onDay date: Date, distanceKm: Double?) async throws -> WorkoutRoute?

    /// Emite un aviso cuando cambian los entrenamientos en Salud
    /// (y una vez al empezar a observar). Vacío donde no hay HealthKit.
    func workoutUpdates() -> AsyncStream<Void>
}
