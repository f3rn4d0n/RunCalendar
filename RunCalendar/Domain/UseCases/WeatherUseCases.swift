import Foundation

/// Trae el clima del día de la carrera para su ubicación.
struct FetchRaceWeatherUseCase: Sendable {
    private let repository: WeatherRepository
    init(repository: WeatherRepository) { self.repository = repository }

    /// `nil` si la carrera no tiene coordenadas o la fecha no tiene datos disponibles.
    func callAsFunction(latitude: Double?, longitude: Double?, date: Date) async throws -> RaceWeather? {
        guard let latitude, let longitude else { return nil }
        return try await repository.weather(latitude: latitude, longitude: longitude, date: date)
    }
}
