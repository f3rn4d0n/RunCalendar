import Foundation

/// Agrega un evento (carrera o entrega de kit) al calendario del sistema.
struct AddToCalendarUseCase: Sendable {
    private let repository: CalendarRepository
    init(repository: CalendarRepository) { self.repository = repository }

    func callAsFunction(_ event: CalendarEvent) async throws {
        try await repository.add(event)
    }
}
