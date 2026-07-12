import Foundation

/// Evento a agregar al calendario del sistema (carrera o entrega de kit).
struct CalendarEvent: Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
}
