import Foundation

/// Rol de una meta frente al plan de entrenamiento. No todas las metas generan sesiones:
/// una sola da forma a la semana, otras solo la configuran, y otras son resultados pasivos.
/// (Ver [Fase 3] en el README: varios objetivos no multiplican el plan.)
enum GoalRole: Sendable, Equatable {
    /// Da forma a la semana (estructura: largo + tempo + series).
    case driver
    /// Configura al driver (es un *parámetro* del mismo plan, no un plan aparte).
    case parameter
    /// Resultado/byproduct: el plan lo apoya, pero no le mete una sesión propia.
    case outcome
}

extension GoalType {
    /// Cómo influye este tipo de meta en la generación del plan.
    /// Conocimiento de dominio, junto a `isAutoMeasured`/`higherIsBetter`.
    var planRole: GoalRole {
        switch self {
        case .raceTime, .vo2max:      return .driver
        case .weeklyVolume, .longRun: return .parameter
        case .weight, .restingHR:     return .outcome
        }
    }
}

/// Clase de sesión de carrera dentro de una semana. El "qué" de cada día.
enum PlannedWorkoutKind: String, Sendable, Equatable, CaseIterable {
    case longRun   = "Tirada larga"
    case tempo     = "Tempo"       // ritmo umbral, la "fase 2"
    case intervals = "Series"
    case easy      = "Fácil"

    /// Días duros del 80/20 (la intensidad pesa más que el volumen).
    var isHard: Bool { self == .tempo || self == .intervals }

    var systemImage: String {
        switch self {
        case .longRun:   return "road.lanes"
        case .tempo:     return "speedometer"
        case .intervals: return "bolt.fill"
        case .easy:      return "figure.run"
        }
    }
}

/// Un día planificado de la semana. Su `id` es el día de la semana (1=domingo … 7=sábado,
/// convención de `Calendar`), consistente con el doc de Firestore `plans/{id}/days/{weekday}`.
struct PlannedDay: Identifiable, Equatable, Sendable {
    var weekday: Int
    var kind: PlannedWorkoutKind
    var targetKm: Double?
    var label: String      // "Series 6 km"
    var detail: String     // guía de ritmo

    var id: String { String(weekday) }

    /// Nombre del día ("lunes", "martes"…), según el calendario actual.
    var weekdayName: String {
        let symbols = Calendar.current.weekdaySymbols
        return (1...7).contains(weekday) ? symbols[weekday - 1] : "—"
    }
}

/// Configuración del plan que da el usuario: cuántos días puede entrenar y cuáles.
struct PlanConfig: Equatable, Sendable {
    var daysPerWeek: Int
    /// Días preferidos (1=domingo … 7=sábado). Vacío → el generador reparte solo.
    var preferredWeekdays: [Int]

    init(daysPerWeek: Int, preferredWeekdays: [Int] = []) {
        self.daysPerWeek = daysPerWeek
        self.preferredWeekdays = preferredWeekdays
    }
}

/// Plan de entrenamiento de una semana, generado desde las metas del atleta (Fase 3).
/// Referencia **una** meta principal (driver) + las secundarias (parámetros/resultados),
/// no un plan por meta.
struct TrainingPlan: Identifiable, Equatable, Sendable {
    let id: String
    var primaryGoalId: String
    var secondaryGoalIds: [String]
    var config: PlanConfig
    var days: [PlannedDay]
    /// Aviso del coach cuando el volumen no cabe sano en los días disponibles (nil si todo cuadra).
    var note: String?
    var weekStart: Date
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        primaryGoalId: String,
        secondaryGoalIds: [String] = [],
        config: PlanConfig,
        days: [PlannedDay],
        note: String? = nil,
        weekStart: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.primaryGoalId = primaryGoalId
        self.secondaryGoalIds = secondaryGoalIds
        self.config = config
        self.days = days
        self.note = note
        self.weekStart = weekStart
        self.createdAt = createdAt
    }

    /// Volumen semanal total planificado (km).
    var totalKm: Double { days.compactMap(\.targetKm).reduce(0, +) }

    /// El día de hoy en el plan, si toca entrenar (para la "misión del día" en Hoy).
    func today(_ now: Date = Date()) -> PlannedDay? {
        let weekday = Calendar.current.component(.weekday, from: now)
        return days.first { $0.weekday == weekday }
    }
}
