import Foundation

/// Fallos al escribir en Salud, para poder decirle al usuario qué hacer.
enum HealthWriteError: LocalizedError {
    /// El usuario no concedió (o revocó) el permiso de escribir esa medida.
    case measureNotAuthorized(BodyMeasure)

    var errorDescription: String? {
        switch self {
        case .measureNotAuthorized(let measure):
            // iOS no vuelve a mostrar la hoja de permisos una vez denegada: la única salida
            // es que el usuario lo active a mano, así que la ruta tiene que ser exacta.
            // Ojo: en la pantalla de Rumbo dentro de Salud hay dos bloques, lectura y escritura,
            // y la medida aparece en ambos. El que hace falta aquí es el de ESCRITURA.
            return "Salud no deja que Rumbo escriba tu \(measure.displayName.lowercased()). Ve a "
                + "Salud › tu foto (arriba a la derecha) › Apps y servicios › Rumbo y enciende "
                + "«\(measure.displayName)» en el bloque «Permitir que Rumbo escriba datos» "
                + "(no el de leer datos, ese ya está activo)."
        }
    }
}

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

    /// Datos actuales del atleta (VO₂max, peso, estatura, edad) para metas y recomendaciones.
    func fetchAthleteMetrics() async throws -> AthleteMetrics

    /// Guarda una medida corporal en Salud (lo único que la app escribe; así se
    /// sincroniza con la app Salud). El valor va en la unidad de `measure` (kg o cm).
    func saveMeasure(_ measure: BodyMeasure, value: Double, date: Date) async throws

    /// Historial de una medida en los últimos `days` días, del más reciente al más viejo.
    func fetchMeasureHistory(_ measure: BodyMeasure, days: Int) async throws -> [MeasurementEntry]

    /// Traza GPS (+ FC por punto) de la corrida de Salud de ese día que mejor
    /// coincide con `distanceKm`. `nil` si no hay corrida con ruta ese día.
    func fetchRoute(onDay date: Date, distanceKm: Double?) async throws -> WorkoutRoute?

    /// Emite un aviso cuando cambian los entrenamientos en Salud
    /// (y una vez al empezar a observar). Vacío donde no hay HealthKit.
    func workoutUpdates() -> AsyncStream<Void>
}
