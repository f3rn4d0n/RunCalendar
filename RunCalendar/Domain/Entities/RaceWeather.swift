import Foundation

/// Condición del cielo (subconjunto de los códigos WMO que nos importan para correr).
enum WeatherCondition: Sendable {
    case clear, partlyCloudy, cloudy, fog, drizzle, rain, heavyRain, snow, thunderstorm

    /// Símbolo SF Symbols que la representa.
    var systemImage: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .fog:          return "cloud.fog.fill"
        case .drizzle:      return "cloud.drizzle.fill"
        case .rain:         return "cloud.rain.fill"
        case .heavyRain:    return "cloud.heavyrain.fill"
        case .snow:         return "cloud.snow.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }

    var label: String {
        switch self {
        case .clear:        return "Despejado"
        case .partlyCloudy: return "Parcialmente nublado"
        case .cloudy:       return "Nublado"
        case .fog:          return "Niebla"
        case .drizzle:      return "Llovizna"
        case .rain:         return "Lluvia"
        case .heavyRain:    return "Lluvia fuerte"
        case .snow:         return "Nieve"
        case .thunderstorm: return "Tormenta"
        }
    }

    /// Mapea un código WMO (Open-Meteo / estándar) a la condición.
    static func fromWMOCode(_ code: Int) -> WeatherCondition {
        switch code {
        case 0:            return .clear
        case 1, 2:         return .partlyCloudy
        case 3:            return .cloudy
        case 45, 48:       return .fog
        case 51, 53, 55, 56, 57: return .drizzle
        case 61, 63, 66:   return .rain
        case 65, 67:       return .heavyRain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 80, 81, 82:   return .rain
        case 95, 96, 99:   return .thunderstorm
        default:           return .cloudy
        }
    }
}

/// Origen del clima mostrado, que define la leyenda y si aplica probabilidad de lluvia.
enum WeatherKind: Sendable {
    case forecast     // evento futuro dentro del rango de pronóstico (~16 días)
    case historical   // evento que ya se realizó: dato real de ese día
    case estimate     // evento futuro lejano: clima típico (histórico del año pasado)

    var legend: String {
        switch self {
        case .forecast:   return "Pronóstico para la hora del evento"
        case .historical: return "Registro histórico del día"
        case .estimate:   return "Clima estimado (mismo día del año pasado) · tentativo"
        }
    }

    /// La probabilidad de lluvia solo tiene sentido en un pronóstico real.
    var showsPrecipitationProbability: Bool { self == .forecast }
}

/// Clima del día de la carrera a la hora del evento (pronóstico, histórico o estimado).
struct RaceWeather: Sendable {
    let temperatureC: Double
    /// Sensación térmica.
    let apparentTemperatureC: Double
    let humidity: Int          // %
    let windKmh: Double
    /// Probabilidad de lluvia. Solo presente en pronósticos reales (futuro cercano).
    let precipitationProbability: Int?
    let condition: WeatherCondition
    let kind: WeatherKind
}
