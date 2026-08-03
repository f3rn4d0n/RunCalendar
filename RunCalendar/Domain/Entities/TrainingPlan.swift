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
    /// Una carrera a la que el atleta **ya está inscrito**. No es un tipo de entrenamiento que el
    /// motor elija: es un hecho de su calendario, y el plan se acomoda alrededor.
    case race      = "Carrera"

    /// Días duros del 80/20 (la intensidad pesa más que el volumen). Una carrera es el día más
    /// duro que existe: se corre a tope y por eso sustituye a la sesión de calidad de la semana.
    var isHard: Bool { self == .tempo || self == .intervals || self == .race }

    var systemImage: String {
        switch self {
        case .longRun:   return "road.lanes"
        case .tempo:     return "speedometer"
        case .intervals: return "bolt.fill"
        case .easy:      return "figure.run"
        case .race:      return "flag.checkered"
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
    /// Id de la carrera si este día **es** una carrera inscrita. No nulo ⇒ el día es un hecho,
    /// no una sugerencia: ya pagaste inscripción para correr esa distancia ese día.
    var raceId: String? = nil

    var id: String { String(weekday) }

    /// Un día fijo no se mueve ni se reprograma: el plan se acomoda alrededor de él.
    var isFixed: Bool { raceId != nil }

    /// Nombre del día ("lunes", "martes"…), según el calendario actual.
    var weekdayName: String {
        let symbols = Calendar.current.weekdaySymbols
        return (1...7).contains(weekday) ? symbols[weekday - 1] : "—"
    }

    /// Posición del día dentro de la semana (0 = lunes … 6 = domingo). Necesaria para decir "ese
    /// día ya pasó": el número de `weekday` es 1=domingo, así que el domingo cierra la semana y aun
    /// así tiene el número más bajo. **Ordena siempre por posición, nunca por `weekday`.**
    static func position(of weekday: Int, calendar: Calendar = .app) -> Int {
        (weekday - calendar.firstWeekday + 7) % 7
    }

    /// El inverso: qué `weekday` de `Calendar` ocupa esa posición de la semana.
    static func weekday(atPosition position: Int, calendar: Calendar = .app) -> Int {
        (position + calendar.firstWeekday - 1) % 7 + 1
    }

    var weekPosition: Int { Self.position(of: weekday) }
}

/// Por qué esta semana **no se mide** contra el plan. Sin esto, la adherencia castiga con 0% al
/// atleta que no entrenó por gripe o lesión — o sea, le dice que falló justo cuando acertó.
///
/// No genera un plan alterno: solo pausa la medición. Inventar un "plan de rehabilitación" sería
/// dar consejo médico que la app no está en posición de dar.
enum WeekStatus: String, CaseIterable, Identifiable, Sendable {
    case injured = "Lesionado"
    case sick    = "Enfermo"
    case deload  = "Descarga"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// ¿Esta semana **no** se entrena? Lesión y enfermedad sí paran; una descarga es entrenar
    /// menos, no dejar de entrenar, así que la sesión del día sigue teniendo sentido.
    var pausesTraining: Bool { self != .deload }

    var systemImage: String {
        switch self {
        case .injured: return "bandage.fill"
        case .sick:    return "thermometer.medium"
        case .deload:  return "arrow.down.circle"
        }
    }

    /// Qué le decimos al atleta en lugar de un porcentaje.
    var message: String {
        switch self {
        case .injured:
            return "Semana marcada como lesión: la adherencia queda en pausa. Recuperarte es el "
                + "entrenamiento de esta semana."
        case .sick:
            return "Semana marcada como enfermedad: la adherencia queda en pausa. Entrenar enfermo "
                + "no adelanta nada y alarga el cuadro."
        case .deload:
            return "Semana de descarga: la adherencia queda en pausa. Menos volumen a propósito, "
                + "para que el cuerpo asimile lo anterior."
        }
    }

    /// Ayuda del selector, para que el atleta sepa cuál elegir.
    var hint: String {
        switch self {
        case .injured: return "Molestia o lesión que impide correr."
        case .sick:    return "Gripe, infección, fiebre."
        case .deload:  return "Bajas el volumen a propósito para asimilar."
        }
    }
}

/// Qué tanto cumpliste el plan de la semana: sesiones y kilómetros hechos vs. planificados.
/// Responde "¿cómo voy respecto al plan?" sin regañar: cuenta lo hecho, no lo fallado.
struct PlanAdherence: Equatable, Sendable {
    let plannedSessions: Int
    let completedSessions: Int
    let plannedKm: Double
    let completedKm: Double
    /// Sesiones de calidad (tempo/series) que el plan pidió esta semana.
    let plannedHardSessions: Int
    /// Sesiones de calidad que de hecho hiciste (por RPE alto, o por caer en un día duro del plan).
    let completedHardSessions: Int
    /// Días duros del plan que ya pasaron sin una sesión de calidad. Los que tientan a "reponer".
    let missedHardDays: Int
    /// Minutos de carrera de la semana. Informativo: el plan da km, no minutos.
    let completedMinutes: Int

    /// Fracción 0–1, topada: correr de más no cuenta como >100% (el plan es un piso, no una cuota).
    static func fraction(_ done: Double, of planned: Double) -> Double {
        planned > 0 ? min(done / planned, 1) : (done > 0 ? 1 : 0)
    }

    var sessionFraction: Double { Self.fraction(Double(completedSessions), of: Double(plannedSessions)) }
    var kmFraction: Double { Self.fraction(completedKm, of: plannedKm) }

    /// El avance que manda es el volumen: 2 sesiones largas pueden cumplir el km de 4 cortas.
    /// Las sesiones entran con la mitad del peso para que la frecuencia también cuente.
    var fraction: Double { (kmFraction * 2 + sessionFraction) / 3 }

    /// Aviso de carga extra. La tentación natural es "reponer" la sesión de calidad que se perdió,
    /// pero reponer no recupera nada: **suma** una sesión dura que la semana no tenía. El plan
    /// reparte duro/fácil precisamente para que el cuerpo asimile; meter calidad de más es la vía
    /// rápida a la lesión y al sobreentrenamiento. `nil` cuando no hay nada que advertir.
    ///
    /// Es un aviso, no un candado: la app no impide entrenar, solo dice el costo.
    static func extraLoadWarning(plannedHard: Int, completedHard: Int, missedHard: Int) -> String? {
        if completedHard > plannedHard {
            return "Llevas \(completedHard) sesiones de calidad y el plan pedía \(plannedHard). "
                + "El exceso de intensidad no acelera nada: baja el resto de la semana a fácil."
        }
        if missedHard > 0 {
            // El problema real no es reprogramar: es *encadenar* intensidad para compensar.
            // Mover el tempo del martes al miércoles suele estar bien; hacerlo el día siguiente
            // a otra sesión dura, no.
            return "Se te fue \(missedHard == 1 ? "una sesión" : "\(missedHard) sesiones") de calidad. "
                + "Si la reprogramas, deja al menos un día fácil o de descanso entre sesiones "
                + "intensas — lo que hace daño es acumularlas para compensar, no moverlas."
        }
        if plannedHard > 0, completedHard >= plannedHard {
            return "Ya cubriste tus \(plannedHard) sesiones de calidad de la semana. "
                + "Lo que falte, en fácil."
        }
        return nil
    }

    /// El aviso para esta semana (ver `extraLoadWarning(plannedHard:completedHard:missedHard:)`).
    var extraLoadWarning: String? {
        Self.extraLoadWarning(plannedHard: plannedHardSessions,
                              completedHard: completedHardSessions,
                              missedHard: missedHardDays)
    }

    /// Cómo va la semana, en una frase.
    var summary: String {
        switch fraction {
        case 1:      return "Semana completa. Así se construye."
        case 0.8...: return "Vas al día con tu plan."
        case 0.5...: return "Vas a medias: aún hay semana para cerrar."
        case 0.01...: return "Arrancaste. Suma una sesión más."
        default:     return "Sin sesiones de carrera esta semana."
        }
    }
}

/// Cómo salió un día de la semana: lo que el plan pedía vs. lo que de hecho corriste. Sirve para
/// explicar **por qué** faltaron sesiones ("el lunes pedía tempo de 8 km y corriste 5.2") en vez
/// de solo decir "2 de 4".
struct PlanDayOutcome: Identifiable, Equatable, Sendable {
    enum Status: Sendable {
        case done       // se cumplió (con tolerancia)
        case partial    // se corrió, pero menos de lo pedido
        case missed     // el día ya pasó y no hubo sesión
        case extra      // era descanso y se corrió
        case rest       // descanso respetado
        case upcoming   // el día aún no llega: nada que juzgar
    }

    let weekday: Int
    let plannedKind: PlannedWorkoutKind?
    let plannedKm: Double?
    let doneKm: Double
    let doneMinutes: Int
    let status: Status

    var id: Int { weekday }

    /// Nadie clava el kilometraje exacto (GPS, semáforos, dar la vuelta antes), así que hay
    /// tolerancia. **Híbrida, no un porcentaje fijo**: un 10% de 4 km son 400 m (irrelevantes) y
    /// un 10% de 20 km son 2 km (media hora de trote). El piso absoluto cubre lo corto y la
    /// fracción cubre lo largo, y manda el mayor de los dos.
    static let toleranceFloorKm = 0.5
    static let toleranceFraction = 0.05

    /// Kilómetros mínimos para que el día cuente como cumplido.
    static func minimumKm(for plannedKm: Double) -> Double {
        plannedKm - max(toleranceFloorKm, plannedKm * toleranceFraction)
    }

    static func status(plannedKm: Double?, doneKm: Double, hasPassed: Bool,
                       beforePlan: Bool = false) -> Status {
        // Un día anterior al plan no se juzga en ninguna dirección: ni "fallado" (no había nada
        // que fallar) ni "extra" (correr no fue salirse de nada).
        if beforePlan { return doneKm > 0 ? .done : .rest }
        guard let plannedKm, plannedKm > 0 else { return doneKm > 0 ? .extra : .rest }
        if doneKm <= 0 { return hasPassed ? .missed : .upcoming }
        return doneKm >= minimumKm(for: plannedKm) ? .done : .partial
    }

    var weekdayName: String {
        let symbols = Calendar.current.weekdaySymbols
        return (1...7).contains(weekday) ? symbols[weekday - 1] : "—"
    }

    /// Lo pedido vs. lo hecho, en una frase. En español llano, sin regañar.
    var summary: String {
        let asked = plannedKm.map { "\(plannedKind?.rawValue ?? "Carrera") de \(Goal.trim($0)) km" }
        let did = "\(Goal.trim(doneKm)) km" + (doneMinutes > 0 ? " en \(doneMinutes) min" : "")
        switch status {
        case .done:
            return "pedía \(asked ?? "—") · hiciste \(did)"
        case .partial:
            let missing = (plannedKm ?? 0) - doneKm
            return "pedía \(asked ?? "—") · hiciste \(did), faltaron \(Goal.trim(missing)) km"
        case .missed:
            return "pedía \(asked ?? "—") · sin sesión ese día"
        case .extra:
            return "era descanso · corriste \(did)"
        case .rest:
            return "descanso"
        case .upcoming:
            return "toca \(asked ?? "—")"
        }
    }
}

/// Plan sugerido desde el historial: config (días/semana + días preferidos) + una meta de volumen,
/// como punto de partida editable (análogo a "Sugerir meta").
struct PlanSuggestion: Equatable, Sendable {
    let config: PlanConfig
    let weeklyVolumeTarget: Double
    let deadline: Date?
    let rationale: String
}

/// Explicación pedagógica de una sesión: qué es, cómo se hace, para qué sirve y por qué ese
/// tamaño. Para que "Series 3.3 km" deje de ser críptico y el atleta entienda qué hacer y por qué.
struct WorkoutGuide: Equatable, Sendable {
    let title: String       // "Series"
    let headline: String    // "5 × 600 m fuerte"
    let pace: String        // ritmo cualitativo (nunca inventamos un ritmo exacto)
    let steps: [GuideStep]  // calentamiento · principal · enfriamiento
    let purpose: String     // para qué sirve
    let rationale: String   // por qué este número (de dónde sale, no una tabla)
    /// La misma sesión en números. `steps` es prosa para leer; esto es para **ejecutarla**.
    let structure: WorkoutStructure
}

/// Un paso de la sesión (calentamiento, bloque principal, enfriamiento).
struct GuideStep: Equatable, Sendable {
    let label: String
    let detail: String
}

/// La sesión en números, no en prosa: lo que hace falta para mandarla al Apple Watch.
/// Los textos de `WorkoutGuide.steps` se derivan de aquí, así que el reloj y la tarjeta
/// **no pueden decir cosas distintas**.
struct WorkoutStructure: Equatable, Sendable {
    var warmupMinutes: Double?
    var intervals: IntervalSpec?  // series
    var steadyKm: Double?         // tramo continuo (tempo, fácil, tirada larga)
    var cooldownMinutes: Double?

    init(warmupMinutes: Double? = nil, intervals: IntervalSpec? = nil,
         steadyKm: Double? = nil, cooldownMinutes: Double? = nil) {
        self.warmupMinutes = warmupMinutes
        self.intervals = intervals
        self.steadyKm = steadyKm
        self.cooldownMinutes = cooldownMinutes
    }
}

/// Un bloque de repeticiones: `reps` × `repMeters` con `recoverySeconds` de trote entre cada una.
struct IntervalSpec: Equatable, Sendable {
    var reps: Int
    var repMeters: Double
    var recoverySeconds: Double
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
    /// Posición de la semana desde la que este plan propone sesiones (0 = la semana entera).
    ///
    /// Mayor que 0 cuando se generó **a media semana**: los días anteriores ya pasaron, así que el
    /// plan ni los ocupa ni los juzga. Sin esto, planificar un sábado te decía que habías fallado
    /// el viernes — un día en el que nunca tuviste plan que seguir.
    var plansFrom: Int
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        primaryGoalId: String,
        secondaryGoalIds: [String] = [],
        config: PlanConfig,
        days: [PlannedDay],
        note: String? = nil,
        weekStart: Date,
        plansFrom: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.primaryGoalId = primaryGoalId
        self.secondaryGoalIds = secondaryGoalIds
        self.config = config
        self.days = days
        self.note = note
        self.weekStart = weekStart
        self.plansFrom = plansFrom
        self.createdAt = createdAt
    }

    /// Volumen semanal total planificado (km).
    var totalKm: Double { days.compactMap(\.targetKm).reduce(0, +) }

    /// El día de hoy en el plan, si toca entrenar (para la "misión del día" en Hoy).
    func today(_ now: Date = Date()) -> PlannedDay? {
        let weekday = Calendar.current.component(.weekday, from: now)
        return days.first { $0.weekday == weekday }
    }

    /// La semana completa (7 días) con la sesión de cada día o `nil` si es descanso. Para mostrar
    /// el ritmo real: sesiones y descansos intercalados, no solo los días que entrenas.
    func fullWeek() -> [(weekday: Int, session: PlannedDay?)] {
        // En orden de la semana (lunes → domingo), no `1...7`, que es el orden de `Calendar` y
        // empieza en domingo. Si no, la vista previa de *Tu plan* abría la semana en domingo
        // mientras el motor la cerraba ahí.
        (0...6).map { position in
            let weekday = PlannedDay.weekday(atPosition: position)
            return (weekday: weekday, session: days.first { $0.weekday == weekday })
        }
    }
}
