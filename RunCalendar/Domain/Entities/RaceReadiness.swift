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

    /// Preparación 0–1: promedio del avance en carrera larga y en volumen semanal vs. lo recomendado.
    var progressFraction: Double {
        func ratio(_ current: Double, _ target: Double) -> Double { target > 0 ? min(current / target, 1) : 1 }
        return (ratio(currentLongRunKm, recommendedLongRunKm) + ratio(currentWeeklyKm, recommendedWeeklyKm)) / 2
    }
}

extension RaceReadiness {
    /// Cuánto se puede subir la tirada larga por semana sin arriesgar lesión. Es el mismo ritmo
    /// que la app ya recomienda en sus notas (1–2 km/semana); aquí se usa el techo para estimar
    /// si el tiempo alcanza.
    static let safeLongRunGainKmPerWeek = 2.0

    /// La última semana antes de la carrera es de afinamiento: no se sube volumen.
    static let taperWeeks = 1

    /// Semanas de trabajo real que quedan antes de la carrera (descontado el afinamiento) y
    /// cuántas pediría cerrar `gapKm` de tirada larga a ritmo seguro.
    /// `nil` sin fecha de referencia o si ya no hay brecha que cerrar.
    ///
    /// Con esto el consejo deja de ser el mismo falte 1 semana o 6 meses: subir la tirada larga
    /// solo se aconseja si `needed <= usable`.
    static func timing(gapKm: Double, weeksAvailable: Int?) -> (usable: Int, needed: Int)? {
        guard let weeksAvailable, gapKm > 0 else { return nil }
        return (usable: max(0, weeksAvailable - taperWeeks),
                needed: Int((gapKm / safeLongRunGainKmPerWeek).rounded(.up)))
    }
}
