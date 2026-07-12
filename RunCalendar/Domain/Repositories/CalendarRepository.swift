import Foundation

/// Contrato para agregar eventos al calendario del sistema. Implementado con EventKit.
protocol CalendarRepository: Sendable {
    /// Agrega el evento al calendario. Lanza si se niega el permiso o falla el guardado.
    func add(_ event: CalendarEvent) async throws
}
