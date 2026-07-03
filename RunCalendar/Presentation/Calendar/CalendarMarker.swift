import SwiftUI

/// Categoría visual de un ítem en el calendario, con su color y etiqueta para la leyenda.
/// El orden de `allCases` define el orden de los puntos y de la leyenda.
enum CalendarMarker: CaseIterable, Identifiable, Hashable {
    case raceCompleted
    case raceRegistered
    case raceNotRegistered
    case training

    var id: Self { self }

    var color: Color {
        switch self {
        case .raceCompleted: return .green
        case .raceRegistered: return .blue
        case .raceNotRegistered: return .orange
        case .training: return .purple
        }
    }

    var label: String {
        switch self {
        case .raceCompleted: return "Carrera completada"
        case .raceRegistered: return "Inscrito"
        case .raceNotRegistered: return "No inscrito"
        case .training: return "Entrenamiento"
        }
    }

    /// Marca correspondiente a una carrera según su estado e inscripción.
    static func forRace(_ race: Race) -> CalendarMarker {
        if race.status == .completed { return .raceCompleted }
        return race.isRegistered ? .raceRegistered : .raceNotRegistered
    }
}
