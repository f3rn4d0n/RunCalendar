import Foundation

/// Tipo de objetivo del atleta. El significado de `targetValue`/`startValue` depende del tipo.
enum GoalType: String, CaseIterable, Identifiable, Sendable {
    case raceTime = "Tiempo en carrera"   // segundos, para una distancia
    case vo2max   = "VO₂max"              // ml/kg/min
    case weight   = "Peso"                // kg

    var id: String { rawValue }
    var displayName: String { rawValue }

    var systemImage: String {
        switch self {
        case .raceTime: return "stopwatch"
        case .vo2max:   return "lungs.fill"
        case .weight:   return "scalemass"
        }
    }

    /// ¿Un valor más alto es mejor? (VO₂max sube; tiempo y peso bajan.)
    var higherIsBetter: Bool { self == .vo2max }
}

/// Meta del atleta (peso, tiempo por distancia, VO₂max). Base de la Fase 1 de la visión.
struct Goal: Identifiable, Equatable, Sendable {
    let id: String
    var type: GoalType
    /// Valor objetivo (segundos | ml·kg⁻¹·min⁻¹ | kg, según `type`).
    var targetValue: Double
    /// Valor al crear la meta, para medir progreso. `nil` si aún no se conocía.
    var startValue: Double?
    /// Distancia objetivo (solo `raceTime`).
    var distance: RaceDiscipline?
    var deadline: Date?
    var notes: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        type: GoalType,
        targetValue: Double,
        startValue: Double? = nil,
        distance: RaceDiscipline? = nil,
        deadline: Date? = nil,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.targetValue = targetValue
        self.startValue = startValue
        self.distance = distance
        self.deadline = deadline
        self.notes = notes
        self.createdAt = createdAt
    }

    /// Título legible: "5K en 25:00", "VO₂max 55", "Peso 78 kg".
    var title: String {
        switch type {
        case .raceTime:
            let dist = distance?.displayName ?? "Carrera"
            return "\(dist) en \(Goal.formatTime(Int(targetValue)))"
        case .vo2max: return "VO₂max \(Goal.trim(targetValue))"
        case .weight: return "Peso \(Goal.trim(targetValue)) kg"
        }
    }

    /// Formatea un valor según el tipo (para "actual"/"meta").
    static func format(_ value: Double, type: GoalType) -> String {
        switch type {
        case .raceTime: return formatTime(Int(value))
        case .vo2max:   return trim(value)
        case .weight:   return "\(trim(value)) kg"
        }
    }

    /// Segundos → "mm:ss" o "h:mm:ss".
    static func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// "mm:ss" o "h:mm:ss" → segundos. `nil` si no parsea.
    static func parseTime(_ text: String) -> Int? {
        let parts = text.split(separator: ":").map { Int($0) }
        guard parts.allSatisfy({ $0 != nil }), (2...3).contains(parts.count) else { return nil }
        let nums = parts.compactMap { $0 }
        return nums.count == 3 ? nums[0] * 3600 + nums[1] * 60 + nums[2] : nums[0] * 60 + nums[1]
    }

    /// Número sin decimales inútiles ("55", "77.5").
    static func trim(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

/// Meta sugerida (valor + fecha + por qué), como punto de partida editable.
/// Una meta sin fecha no es accionable, por eso la recomendación también propone plazo.
struct GoalRecommendation: Equatable, Sendable {
    let targetValue: Double
    let deadline: Date?
    let rationale: String
}

/// Progreso de una meta contra el valor actual (de PRs, VO₂max o peso).
struct GoalProgress: Equatable, Sendable {
    let achieved: Bool
    /// Fracción 0–1 para la barra (necesita `startValue`); `nil` si no se puede medir.
    let fraction: Double?
    let currentText: String   // "26:10", "51.2", "—"
    let deltaText: String     // "faltan 1:10", "¡Logrado!", "Registra el dato"
}
