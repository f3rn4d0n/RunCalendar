import Foundation

/// Contrato de persistencia de las semanas ya decididas. Implementado con Firestore.
///
/// Existe para que las semanas **pasadas** sobrevivan. La foto de la semana en curso vivía en
/// `UserDefaults`, que alcanzaba para que el plan dejara de reescribirse pero no para mirar atrás:
/// sin el plan que viste entonces, la adherencia histórica es imposible — regenerarlo hoy daría
/// otro plan, porque depende de tu volumen de hoy.
protocol WeekPlanRepository: Sendable {
    func save(_ week: FrozenWeek, userID: String) async throws
    /// La semana que empieza en `weekStart`, si se decidió.
    func fetch(weekStart: Date, userID: String) async throws -> FrozenWeek?
    /// Las últimas `weeks` semanas guardadas, de la más reciente a la más vieja.
    func recent(weeks: Int, userID: String) async throws -> [FrozenWeek]
}
