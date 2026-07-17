import Foundation

/// Entrenamiento de carrera leído de Apple Salud (solo lectura).
/// Se usa para sugerir importarlo como `TrainingSession` sin recapturarlo a mano.
struct HealthWorkout: Identifiable, Equatable, Sendable {
    let id: String        // UUID del HKWorkout
    let date: Date
    let distanceKm: Double
    let durationMin: Int?
    /// Frecuencia cardiaca promedio (lpm), si el workout la registró.
    let avgHeartRate: Int?
}
