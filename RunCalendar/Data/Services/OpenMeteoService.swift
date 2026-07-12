import Foundation

/// Implementación de `WeatherRepository` sobre Open-Meteo (https://open-meteo.com):
/// API de clima gratuita, sin API key. Usa el endpoint de pronóstico para fechas
/// recientes/futuras y el de archivo (histórico) para carreras antiguas.
final class OpenMeteoService: WeatherRepository {

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    private let hourlyFields = "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code"

    func weather(latitude: Double, longitude: Double, date: Date) async throws -> RaceWeather? {
        let days = daysFromToday(date)
        // El tipo (leyenda + si aplica prob. de lluvia) depende de la FECHA del evento,
        // no del endpoint: una carrera pasada reciente igual se lee del endpoint de
        // pronóstico, pero se presenta como histórica.
        let kind: WeatherKind
        let queryDate: Date
        if days > 16 {
            kind = .estimate
            queryDate = Self.sameDayLastYear(date) // sin pronóstico tan lejos: clima típico
        } else if days >= 0 {
            kind = .forecast
            queryDate = date
        } else {
            kind = .historical
            queryDate = date
        }

        // El endpoint de archivo cubre el pasado profundo; el de pronóstico, ~92 días atrás y 16 adelante.
        let useArchive = daysFromToday(queryDate) < -92
        let wantPrecip = kind.showsPrecipitationProbability && !useArchive
        let dayString = Self.dayFormatter.string(from: queryDate)

        var components = URLComponents(string: useArchive
            ? "https://archive-api.open-meteo.com/v1/archive"
            : "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "hourly", value: wantPrecip ? hourlyFields + ",precipitation_probability" : hourlyFields),
            .init(name: "start_date", value: dayString),
            .init(name: "end_date", value: dayString),
            .init(name: "timezone", value: "auto"),
            .init(name: "wind_speed_unit", value: "kmh")
        ]
        guard let url = components.url else { return nil }

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let dto = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return build(from: dto.hourly, raceHour: Calendar.current.component(.hour, from: date), kind: kind)
    }

    /// Toma la hora de la traza correspondiente a la hora del evento.
    private func build(from hourly: OpenMeteoResponse.Hourly, raceHour: Int, kind: WeatherKind) -> RaceWeather? {
        guard !hourly.time.isEmpty else { return nil }
        let i = min(max(raceHour, 0), hourly.time.count - 1)   // arreglo del día: índice = hora
        guard i < hourly.temperature_2m.count else { return nil }

        var precip: Int?
        if kind.showsPrecipitationProbability { precip = hourly.precipitation_probability?[safe: i] ?? nil }

        return RaceWeather(
            temperatureC: hourly.temperature_2m[i],
            apparentTemperatureC: hourly.apparent_temperature[safe: i] ?? hourly.temperature_2m[i],
            humidity: hourly.relative_humidity_2m[safe: i] ?? 0,
            windKmh: hourly.wind_speed_10m[safe: i] ?? 0,
            precipitationProbability: precip,
            condition: .fromWMOCode(hourly.weather_code[safe: i] ?? 3),
            kind: kind
        )
    }

    private static func sameDayLastYear(_ date: Date) -> Date {
        Calendar.current.date(byAdding: .year, value: -1, to: date) ?? date
    }

    private func daysFromToday(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}

/// Respuesta de Open-Meteo (solo los campos horarios que pedimos).
private struct OpenMeteoResponse: Decodable {
    let hourly: Hourly
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let apparent_temperature: [Double]
        let relative_humidity_2m: [Int]
        let wind_speed_10m: [Double]
        let weather_code: [Int]
        let precipitation_probability: [Int?]?
    }
}

private extension Array {
    /// Acceso seguro por índice (evita crash si la traza viene corta o con huecos).
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
