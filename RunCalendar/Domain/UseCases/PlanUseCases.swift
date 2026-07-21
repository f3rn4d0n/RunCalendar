import Foundation

/// Infiere la **meta principal** (driver) del plan: la que da forma a la semana.
/// Regla: entre las metas driver (tiempo/VO₂max), gana la de deadline más cercano; las que no
/// tienen fecha van al final; empate por antigüedad. Con `override` el usuario la fija a mano.
/// Devuelve `nil` si no hay ninguna meta que pueda dar estructura a un plan de carrera.
struct InferPrimaryGoalUseCase: Sendable {
    func callAsFunction(_ goals: [Goal], override: String? = nil) -> Goal? {
        if let override, let pinned = goals.first(where: { $0.id == override }) { return pinned }
        let drivers = goals.filter { $0.type.planRole == .driver }
        return drivers.min { lhs, rhs in
            switch (lhs.deadline, rhs.deadline) {
            case let (l?, r?):  return l < r
            case (_?, nil):     return true      // con fecha antes que sin fecha
            case (nil, _?):     return false
            case (nil, nil):    return lhs.createdAt < rhs.createdAt
            }
        }
    }
}

/// Genera el plan de una semana desde la meta principal + sus parámetros, de forma **determinista**
/// (sin IA, mismo espíritu que "Sugerir meta"). Reglas estándar:
/// - **Estructura por días/semana**: 3 → tirada larga + tempo (umbral) + series; menos/más días
///   quitan o agregan rodajes fáciles.
/// - **Volumen**: progresa desde tu volumen actual (~+8%/sem, techo 10%), sin pasar el target.
/// - **Tirada larga**: +~1 km/sem hacia su target; acotada para no ser una corrida monstruo y para
///   ser siempre el día más largo.
/// - **80/20**: series y tempo aportan poco volumen (el 20% duro); los fáciles se llevan el grueso.
/// - **Taper**: la última semana antes de la meta baja el volumen.
///
/// `// ponytail:` v1 lineal. Periodización real (mesociclos, deloads cada 4ª sem, taper por tipo de
/// carrera) y espaciado inteligente de días duros se difieren; llegan con la IA si de verdad hacen falta.
struct GeneratePlanUseCase: Sendable {

    /// Todo lo que el motor necesita. El llamador calcula `currentWeeklyKm`/`currentLongRunKm`
    /// desde las `TrainingSession` (mismo origen que la carga/ACWR).
    struct Input: Sendable {
        var primary: Goal
        var secondaries: [Goal]        // parámetros (volumen/tirada) + resultados (peso/FC)
        var config: PlanConfig
        var currentWeeklyKm: Double
        var currentLongRunKm: Double?
        var weekStart: Date
        var now: Date

        init(primary: Goal, secondaries: [Goal] = [], config: PlanConfig,
             currentWeeklyKm: Double, currentLongRunKm: Double? = nil,
             weekStart: Date = Date(), now: Date = Date()) {
            self.primary = primary
            self.secondaries = secondaries
            self.config = config
            self.currentWeeklyKm = currentWeeklyKm
            self.currentLongRunKm = currentLongRunKm
            self.weekStart = weekStart
            self.now = now
        }
    }

    func callAsFunction(_ input: Input) -> TrainingPlan {
        let days = clamp(input.config.daysPerWeek, 2, 6)
        let volumeTarget  = input.secondaries.first { $0.type == .weeklyVolume }?.targetValue
        let longRunTarget = input.secondaries.first { $0.type == .longRun }?.targetValue

        // Volumen de la semana. Sin historial (arranque en frío) usa un default por días disponibles.
        let base = input.currentWeeklyKm > 0 ? input.currentWeeklyKm : Double(days) * 5
        var weekKm = min(base * 1.08, volumeTarget ?? base * 1.08)
        weekKm = max(weekKm, base)                       // nunca por debajo del actual

        // Taper: última semana antes de la meta.
        let tapering = weeksLeft(input.primary.deadline, input.now).map { $0 <= 1 } ?? false
        if tapering { weekKm *= 0.6 }

        // Tirada larga: progresa +1 km/sem hacia su target si tenemos el dato; si no, una fracción
        // del volumen. Acotada a [fracción base, 60%] para que sea siempre el día más largo.
        let frac = longFraction(days: days)
        let progressed = input.currentLongRunKm.map { min($0 + 1, longRunTarget ?? .greatestFiniteMagnitude) }
        let longKm = round1(clampD(progressed ?? weekKm * frac, weekKm * frac, weekKm * 0.6))

        // Reparto del resto por pesos de rol (el largo ya está fuera del pool).
        let structure = structure(for: days)             // ordenado, tirada larga al final
        let others = structure.filter { $0 != .longRun }
        let weightSum = others.map(roleWeight).reduce(0, +)
        let remaining = max(0, weekKm - longKm)

        func km(for kind: PlannedWorkoutKind) -> Double {
            kind == .longRun ? longKm
                             : (weightSum > 0 ? round1(remaining * roleWeight(kind) / weightSum) : 0)
        }

        // Asigna días de la semana: preferidos (o reparto por defecto), la tirada larga al último.
        let weekdays = weekdays(for: input.config, count: structure.count)
        let planned: [PlannedDay] = zip(weekdays, structure).map { weekday, kind in
            let distance = km(for: kind)
            return PlannedDay(weekday: weekday, kind: kind, targetKm: distance,
                              label: label(kind, km: distance), detail: detail(kind))
        }

        return TrainingPlan(
            primaryGoalId: input.primary.id,
            secondaryGoalIds: input.secondaries.map(\.id),
            config: PlanConfig(daysPerWeek: days, preferredWeekdays: input.config.preferredWeekdays),
            days: planned,
            weekStart: input.weekStart
        )
    }

    // MARK: - Reglas (constantes calibrables)

    /// Estructura de la semana por días disponibles. La tirada larga siempre al final para que
    /// caiga en el día más tardío (típicamente fin de semana).
    private func structure(for days: Int) -> [PlannedWorkoutKind] {
        switch days {
        case 2:  return [.tempo, .longRun]
        case 3:  return [.intervals, .tempo, .longRun]
        case 4:  return [.intervals, .tempo, .easy, .longRun]
        case 5:  return [.intervals, .tempo, .easy, .easy, .longRun]
        default: return [.intervals, .tempo, .easy, .easy, .easy, .longRun]   // 6
        }
    }

    /// Fracción del volumen para la tirada larga según días/semana. Elegida para que el largo sea
    /// siempre el día más largo (con menos días, cada sesión pesa más).
    private func longFraction(days: Int) -> Double {
        switch days {
        case 2:  return 0.55
        case 3:  return 0.40
        case 4:  return 0.38
        case 5:  return 0.35
        default: return 0.33
        }
    }

    /// Peso relativo de volumen de los días que no son la tirada larga (series aporta menos km).
    private func roleWeight(_ kind: PlannedWorkoutKind) -> Double {
        switch kind {
        case .intervals: return 0.8
        case .tempo:     return 1.0
        case .easy:      return 1.0
        case .longRun:   return 0
        }
    }

    private func label(_ kind: PlannedWorkoutKind, km: Double) -> String {
        "\(kind.rawValue) \(Goal.trim(km)) km"
    }

    private func detail(_ kind: PlannedWorkoutKind) -> String {
        switch kind {
        case .longRun:   return "Ritmo cómodo y conversable; construye base aeróbica."
        case .tempo:     return "Ritmo umbral (cómodo-duro), tu \"fase 2\"."
        case .intervals: return "Repeticiones a ritmo ~5K con recuperación entre cada una."
        case .easy:      return "Rodaje suave de recuperación."
        }
    }

    /// Días de la semana a usar. Si los preferidos alcanzan, se toman ordenados; si no, un reparto
    /// por defecto espaciado (Mar/Jue/Sáb/Lun/Mié/Dom).
    private func weekdays(for config: PlanConfig, count: Int) -> [Int] {
        let prefs = Array(Set(config.preferredWeekdays)).filter { (1...7).contains($0) }.sorted()
        if prefs.count >= count { return Array(prefs.prefix(count)) }
        let spread = [3, 5, 7, 2, 4, 1]                  // Calendar: 1=Dom … 7=Sáb
        return Array(spread.prefix(count)).sorted()
    }

    private func weeksLeft(_ deadline: Date?, _ now: Date) -> Int? {
        guard let deadline else { return nil }
        let days = Calendar.current.dateComponents([.day], from: now, to: deadline).day ?? 0
        return days >= 0 ? days / 7 : nil
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(max(v, lo), hi) }
    private func clampD(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }
    private func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}

#if DEBUG
extension GeneratePlanUseCase {
    /// Check en aislamiento (sin target de tests): falla ruidoso si el motor se rompe.
    /// Se dispara desde `PlanSelfCheckPreview` (canvas de Xcode).
    static func selfCheck() -> String {
        let gen = GeneratePlanUseCase()
        let deadline = Calendar.current.date(byAdding: .day, value: 84, to: Date())
        let goal = Goal(type: .raceTime, targetValue: 1500, distance: .tenK, deadline: deadline)
        let plan = gen(.init(
            primary: goal,
            config: PlanConfig(daysPerWeek: 3, preferredWeekdays: [3, 5, 7]),
            currentWeeklyKm: 30, currentLongRunKm: 12
        ))
        let kinds = Set(plan.days.map(\.kind))
        assert(kinds.isSuperset(of: [.longRun, .tempo, .intervals]),
               "3 días debe incluir tirada larga + tempo + series")
        assert(plan.totalKm <= 30 * 1.10 + 0.5, "el volumen no debe exceder +10% del actual")
        let longKm = plan.days.first { $0.kind == .longRun }?.targetKm ?? 0
        assert(longKm == plan.days.compactMap(\.targetKm).max(),
               "la tirada larga debe ser el día más largo")
        assert(plan.days.map(\.weekday) == [3, 5, 7], "debe respetar los días preferidos")
        return "OK · \(plan.days.count) días · \(Goal.trim(plan.totalKm)) km/sem · "
             + "larga \(Goal.trim(longKm)) km"
    }
}
#endif
