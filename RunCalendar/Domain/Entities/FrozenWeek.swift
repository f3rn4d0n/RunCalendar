import Foundation

/// La semana ya decidida: el plan que se generó al empezarla y que **no cambia** aunque cambien tus
/// datos durante los días siguientes.
///
/// Existe porque el plan era una función pura de tu volumen de hoy, y tu volumen de hoy incluye lo
/// que corriste ayer. Cada carrera que registrabas subía la base y el motor recalculaba objetivos
/// más altos: **el plan del lunes no era el del jueves**, y la adherencia te medía contra el del
/// jueves. "Seguir el plan" era imposible por construcción.
///
/// ## Qué la invalida y qué no
///
/// Se regenera cuando cambia lo que **declaraste** —días, días preferidos, qué buscas, tus
/// carreras de la semana— y **no** cuando cambian tus **datos** de entrenamiento. Es la misma
/// distinción que recorre todo el motor: los hechos se observan, las decisiones se declaran, y solo
/// una decisión tuya rehace la semana.
///
/// Sin esa regla, congelar no serviría: cualquier carrera registrada rompería la foto y volveríamos
/// al punto de partida.
struct FrozenWeek: Codable, Equatable, Sendable {
    let weekStart: Date
    /// Resumen de las decisiones con las que se generó. Si cambia, la foto ya no vale.
    let fingerprint: String
    let plan: TrainingPlan

    /// ¿Sirve todavía para esta semana y estas decisiones?
    func isValid(for weekStart: Date, fingerprint: String, calendar: Calendar = .app) -> Bool {
        calendar.isDate(self.weekStart, inSameDayAs: weekStart) && self.fingerprint == fingerprint
    }

    /// Huella de las decisiones del atleta. Deliberadamente **no** incluye volumen, carga ni
    /// sesiones completadas: son datos, y los datos no rehacen la semana.
    static func fingerprint(config: PlanConfig, intake: AthleteIntake,
                            raceIds: [String], goalId: String?, goalTarget: Double?) -> String {
        [
            "d\(config.daysPerWeek)",
            "w\(config.preferredWeekdays.sorted().map(String.init).joined(separator: "-"))",
            "i\(intake.intent.rawValue)",
            "h\(intake.hasHills)",
            "g\(goalId ?? "-")",
            "t\(goalTarget.map { String(format: "%.1f", $0) } ?? "-")",
            "r\(raceIds.sorted().joined(separator: "-"))"
        ].joined(separator: "|")
    }
}
