import Foundation

/// Evento a agregar al calendario del sistema (carrera o entrega de kit).
struct CalendarEvent: Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    /// Coordenadas para geolocalizar el evento (→ mapa y tiempo de viaje del sistema).
    let latitude: Double?
    let longitude: Double?
    /// Enlace del evento (p. ej. la página de inscripción).
    let url: URL?
    /// Alarma relativa, en minutos antes del inicio (nil = sin alarma).
    let alarmMinutesBefore: Int?

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        url: URL? = nil,
        alarmMinutesBefore: Int? = nil
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.latitude = latitude
        self.longitude = longitude
        self.url = url
        self.alarmMinutesBefore = alarmMinutesBefore
    }
}
