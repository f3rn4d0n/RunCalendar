import SwiftUI

/// Categoría visual de un ítem en el calendario, con su color y etiqueta para la leyenda.
/// El orden de `allCases` define el orden de los puntos y de la leyenda.
enum CalendarMarker: CaseIterable, Identifiable, Hashable {
    case eventComplete
    case raceRegistered
    case raceNotRegistered
    case training
    case trainingOther

    var id: Self { self }

    var color: Color {
        switch self {
        case .eventComplete: return Neon.green
        case .raceRegistered: return Neon.teal
        case .raceNotRegistered: return Neon.orange
        case .training: return Neon.purple
        case .trainingOther: return Neon.pink
        }
    }

    var label: String {
        switch self {
        case .eventComplete: return "Evento completado"
        case .raceRegistered: return "Inscrito"
        case .raceNotRegistered: return "No inscrito"
        case .training: return "Carrera (entreno)"
        case .trainingOther: return "Otro ejercicio"
        }
    }

    /// Marca correspondiente a una carrera según su estado e inscripción.
    static func forRace(_ race: Race) -> CalendarMarker {
        if race.status == .completed { return .eventComplete }
        return race.isRegistered ? .raceRegistered : .raceNotRegistered
    }

    /// Carrera = púrpura; caminata/senderismo/CrossFit = otro color.
    static func forTraining(_ type: TrainingType) -> CalendarMarker {
        type == .running ? .training : .trainingOther
    }
}
