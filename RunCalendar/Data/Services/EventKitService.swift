import Foundation
import EventKit

/// Implementación de `CalendarRepository` sobre EventKit.
/// Pide acceso **solo de escritura** (iOS 17+): agregar eventos sin leer el calendario.
final class EventKitService: CalendarRepository {

    private let store = EKEventStore()

    func add(_ event: CalendarEvent) async throws {
        let granted = try await store.requestWriteOnlyAccessToEvents()
        guard granted else {
            throw AppError.unknown("No se pudo acceder al Calendario. Revisa los permisos en Ajustes.")
        }
        guard let calendar = store.defaultCalendarForNewEvents else {
            throw AppError.unknown("No hay un calendario predeterminado para agregar el evento.")
        }

        let ekEvent = EKEvent(eventStore: store)
        ekEvent.calendar = calendar
        ekEvent.title = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.location = event.location
        ekEvent.notes = event.notes

        do {
            try store.save(ekEvent, span: .thisEvent)
        } catch {
            throw AppError.unknown("No se pudo guardar el evento: \(error.localizedDescription)")
        }
    }
}
