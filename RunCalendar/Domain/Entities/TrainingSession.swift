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
    /// FC promedio (lpm), típicamente de un workout importado de Salud.
    var avgHeartRate: Int?

    // Específicos de CrossFit
    var wod: String?          // descripción del WOD

    var completed: Bool
    var notes: String
    /// Entrenamiento prioritario (p. ej. un black challenge de crossfit).
    var isPriority: Bool
    /// Evento objetivo (id de la carrera) al que apunta este entrenamiento.
    var targetRaceID: String?
    /// Esfuerzo percibido (RPE, 1–10). Base para calibrar la carga.
    var rpe: Int?

    /// Carga de sesión (RPE × minutos), métrica estándar de carga de entrenamiento.
    var sessionLoad: Int? {
        guard let rpe, let durationMin else { return nil }
        return rpe * durationMin
    }

    init(
        id: String = UUID().uuidString,
        date: Date,
        type: TrainingType,
        title: String,
        details: String = "",
        durationMin: Int? = nil,
        distanceKm: Double? = nil,
        targetPace: String? = nil,
        avgHeartRate: Int? = nil,
        wod: String? = nil,
        completed: Bool = false,
        notes: String = "",
        isPriority: Bool = false,
        targetRaceID: String? = nil,
        rpe: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.title = title
        self.details = details
        self.durationMin = durationMin
        self.distanceKm = distanceKm
        self.targetPace = targetPace
        self.avgHeartRate = avgHeartRate
        self.wod = wod
        self.completed = completed
        self.notes = notes
        self.isPriority = isPriority
        self.targetRaceID = targetRaceID
        self.rpe = rpe
    }
}
