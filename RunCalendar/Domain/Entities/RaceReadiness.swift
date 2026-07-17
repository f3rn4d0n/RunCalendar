import Foundation

/// Nivel de preparación estimado para una distancia.
enum ReadinessLevel: String, Sendable {
    case ready = "Listo"
    case almost = "Casi listo"
    case building = "En construcción"

    var systemImage: String {
        switch self {
        case .ready: return "checkmark.seal.fill"
        case .almost: return "hourglass"
        case .building: return "figure.run"
        }
    }

    /// Orden por urgencia de preparación: lo que más falta preparar va primero.
    var prepPriority: Int {
        switch self {
        case .building: return 0
        case .almost:   return 1
        case .ready:    return 2
        }
    }
}

/// Estimado de preparación para una distancia objetivo.
struct RaceReadiness: Identifiable, Equatable, Sendable {
    let distance: RaceDiscipline
    let level: ReadinessLevel
    /// Carrera más larga actual del usuario (km).
    let currentLongRunKm: Double
    /// Distancia de "long run" recomendada para llegar listo (km).
    let recommendedLongRunKm: Double
    /// Volumen semanal actual (km).
    let currentWeeklyKm: Double
    /// Volumen semanal recomendado (km).
    let recommendedWeeklyKm: Double
    /// Nota corta para la fila.
    let note: String
    /// Recomendaciones detalladas de qué mejorar.
    let recommendations: [String]

    var id: String { distance.rawValue }
}
