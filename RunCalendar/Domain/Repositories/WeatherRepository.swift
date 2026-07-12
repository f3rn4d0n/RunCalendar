import Foundation

/// Contrato de acceso al clima. Implementado hoy con Open-Meteo (gratis, sin key);
/// mañana, para publicar, se puede sustituir por un `WeatherKitService` sin tocar
/// dominio ni UI (Dependency Inversion).
protocol WeatherRepository: Sendable {
    /// Clima del `date` en la ubicación dada (pronóstico si es futuro, histórico si es
    /// pasado). `nil` si la fecha cae fuera del rango con datos (p. ej. muy a futuro).
    func weather(latitude: Double, longitude: Double, date: Date) async throws -> RaceWeather?
}
