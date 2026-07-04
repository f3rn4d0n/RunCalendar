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
}

/// Estimado de preparación para una distancia objetivo.
struct RaceReadiness: Identifiable, Equatable, Sendable {
    let distance: RaceDiscipline
    let level: ReadinessLevel
    /// Distancia de "long run" recomendada para llegar listo (km).
    let recommendedLongRunKm: Double
    /// Nota orientativa para el usuario.
    let note: String

    var id: String { distance.rawValue }
}
