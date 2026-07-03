import Foundation

/// Contrato para agendar recordatorios locales de eventos.
/// La capa Data lo implementa con notificaciones locales del sistema.
protocol ReminderScheduler: Sendable {
    /// Pide permiso al usuario para enviar notificaciones. Devuelve si fue concedido.
    func requestAuthorization() async -> Bool

    /// Reagenda todos los recordatorios a partir de las carreras y entrenamientos dados
    /// (cancela los previos y agenda los vigentes).
    func reschedule(races: [Race], trainings: [TrainingSession]) async

    /// Cancela todos los recordatorios pendientes.
    func cancelAll() async
}
