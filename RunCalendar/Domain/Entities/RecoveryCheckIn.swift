import Foundation

/// Registro diario de cómo se siente el usuario, con lo que el modelo predijo ese día.
/// Es la "verdad" contra la que luego se calibrará la heurística de recuperación.
struct RecoveryCheckIn: Identifiable, Equatable, Sendable {
    /// Día del registro (a medianoche); un check-in por día.
    let date: Date
    /// Sensación de recuperación reportada, 1 (agotado) a 5 (fresco).
    let feeling: Int
    /// Horas de recuperación que el modelo estimó ese día (para comparar).
    let predictedRemainingHours: Int
    let hrv: Double?
    let baselineHRV: Double?
    let sleepHours: Double?

    var id: Date { date }
}
