import Foundation

/// Preferencias del usuario sobre qué recordatorios recibir y cuándo.
struct ReminderPreferences: Codable, Equatable, Sendable {
    /// Días de aviso anticipado antes del evento (0 = sin aviso anticipado).
    var leadDays: Int
    /// Aviso la víspera del evento.
    var dayBefore: Bool
    /// Aviso el día del evento.
    var dayOf: Bool
    /// Aviso de la entrega de kit.
    var kit: Bool
    /// Avisos de entrenamientos pendientes (a la hora de la sesión).
    var trainings: Bool
    /// Hora (0-23) para los avisos basados en fecha (anticipado, víspera, día).
    var reminderHour: Int

    static let `default` = ReminderPreferences(
        leadDays: 7,
        dayBefore: true,
        dayOf: true,
        kit: true,
        trainings: true,
        reminderHour: 9
    )
}
