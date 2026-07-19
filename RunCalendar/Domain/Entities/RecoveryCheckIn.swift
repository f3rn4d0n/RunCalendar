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
    /// Carga reciente (minutos-esfuerzo, 72 h) ese día. Base para calibrar por carga.
    let loadMinutes: Int?

    var id: Date { date }

    /// La predicción del modelo mapeada a la misma escala 1–5 de la sensación
    /// (menos horas restantes = más recuperado = número más alto), para compararlas.
    var modelFeeling: Int {
        switch predictedRemainingHours {
        case 0:      return 5
        case 1...12: return 4
        case 13...24: return 3
        case 25...48: return 2
        default:     return 1
        }
    }
}
