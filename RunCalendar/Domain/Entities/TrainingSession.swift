import Foundation

/// Tipo de entrenamiento soportado en v1.
enum TrainingType: String, CaseIterable, Identifiable, Sendable {
    case crossfit = "CrossFit"
    case running = "Carrera"

    var id: String { rawValue }
    var displayName: String { rawValue }
    var systemImage: String {
        switch self {
        case .crossfit: return "dumbbell.fill"
        case .running: return "figure.run"
        }
    }
}

/// Sesión de entrenamiento (CrossFit o carrera).
struct TrainingSession: Identifiable, Equatable, Sendable {
    let id: String
    var date: Date
    var type: TrainingType
    var title: String
    var details: String
    var durationMin: Int?

    // Específicos de carrera
    var distanceKm: Double?
    var targetPace: String?   // p. ej. "5:30 min/km"

    // Específicos de CrossFit
    var wod: String?          // descripción del WOD

    var completed: Bool
    var notes: String

    init(
        id: String = UUID().uuidString,
        date: Date,
        type: TrainingType,
        title: String,
        details: String = "",
        durationMin: Int? = nil,
        distanceKm: Double? = nil,
        targetPace: String? = nil,
        wod: String? = nil,
        completed: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.title = title
        self.details = details
        self.durationMin = durationMin
        self.distanceKm = distanceKm
        self.targetPace = targetPace
        self.wod = wod
        self.completed = completed
        self.notes = notes
    }
}
