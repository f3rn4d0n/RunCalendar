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

/// Explica una sesión planificada en lenguaje de atleta: qué es, cómo se hace (con esquema de
/// repeticiones concreto para las series), para qué sirve y por qué ese tamaño. Determinista y sin
/// inventar ritmos exactos (los deja cualitativos), fiel al principio de "nunca un dato inventado".
struct DescribeWorkoutUseCase: Sendable {
    func callAsFunction(_ day: PlannedDay) -> WorkoutGuide {
        let km = day.targetKm ?? 0
        switch day.kind {
        case .intervals: return intervals(km)
        case .tempo:     return tempo(km)
        case .longRun:   return longRun(km)
        case .easy:      return easy(km)
        }
    }

    /// Series: el volumen "fuerte" se parte en repeticiones. Distancia de repetición según el total,
    /// para que salgan entre ~4 y ~8 repeticiones (el rango útil de una sesión de calidad).
    private func intervals(_ km: Double) -> WorkoutGuide {
        let qualityM = km * 1000
        let repM = qualityM <= 2400 ? 400.0 : (qualityM <= 4000 ? 600.0 : 800.0)
        let reps = max(3, Int((qualityM / repM).rounded()))
        let recovery = repM <= 400 ? "60–90 s" : "90 s – 2 min"
        return WorkoutGuide(
            title: "Series",
            headline: "\(reps) × \(Int(repM)) m fuerte",
            pace: "Ritmo ~5K: rápido pero repetible, esfuerzo 8–9 de 10 (no un sprint).",
            steps: [
                GuideStep(label: "Calentamiento",
                          detail: "10–15 min de trote muy suave + 3–4 aceleraciones cortas."),
                GuideStep(label: "Bloque principal",
                          detail: "\(reps) repeticiones de \(Int(repM)) m a ritmo ~5K, con "
                              + "\(recovery) de trote suave (o caminar) entre cada una."),
                GuideStep(label: "Enfriamiento", detail: "10 min de trote muy suave.")
            ],
            purpose: "Suben tu velocidad y tu VO₂max: enseñan al cuerpo a correr rápido y a tolerar "
                + "el esfuerzo. Es el estímulo de intensidad de la semana.",
            rationale: "Los ~\(Goal.trim(km)) km fuertes son cerca del 15% de tu volumen semanal, "
                + "topados a propósito para que sean calidad sin vaciarte. Por eso el número no es "
                + "redondo: sale de tu volumen actual, no de una tabla genérica."
        )
    }

    private func tempo(_ km: Double) -> WorkoutGuide {
        WorkoutGuide(
            title: "Tempo",
            headline: "\(Goal.trim(km)) km continuos a ritmo umbral",
            pace: "Cómodo-duro: podrías decir pocas palabras, no mantener una charla. ~ritmo de 10–15K.",
            steps: [
                GuideStep(label: "Calentamiento", detail: "10 min de trote suave."),
                GuideStep(label: "Bloque principal",
                          detail: "\(Goal.trim(km)) km continuos a ritmo umbral, sin parar."),
                GuideStep(label: "Enfriamiento", detail: "10 min de trote suave.")
            ],
            purpose: "Sube tu umbral de lactato: el ritmo más rápido que puedes sostener sin "
                + "fundirte. Es lo que más mueve tu marca en carreras largas.",
            rationale: "Un bloque continuo moderado; su tamaño está topado (≤ 14 km) para que sea "
                + "sostenible y no se convierta en una carrera de práctica."
        )
    }

    private func longRun(_ km: Double) -> WorkoutGuide {
        WorkoutGuide(
            title: "Tirada larga",
            headline: "\(Goal.trim(km)) km a ritmo cómodo",
            pace: "Conversable: deberías poder hablar en frases completas todo el tiempo.",
            steps: [
                GuideStep(label: "La sesión",
                          detail: "Corre \(Goal.trim(km)) km a ritmo suave y constante. Si te "
                              + "cuesta hablar, vas muy rápido: baja el ritmo.")
            ],
            purpose: "Construye tu base aeróbica y tu resistencia: acostumbra al cuerpo a usar grasa "
                + "y a aguantar tiempo en pie. Es la sesión más importante para distancias largas.",
            rationale: "Crece ~1 km por semana hacia tu meta de tirada, y está topada al 60% de tu "
                + "volumen (máx. 30 km) para no meter una corrida que te lesione."
        )
    }

    private func easy(_ km: Double) -> WorkoutGuide {
        WorkoutGuide(
            title: "Rodaje fácil",
            headline: "\(Goal.trim(km)) km muy suave",
            pace: "Muy fácil, ritmo de recuperación: deberías terminar sintiendo que podrías seguir.",
            steps: [
                GuideStep(label: "La sesión",
                          detail: "Corre \(Goal.trim(km)) km sin prisa. El objetivo es sumar "
                              + "volumen sin fatiga, no ir rápido.")
            ],
            purpose: "Recuperación activa y volumen aeróbico barato: suma kilómetros que construyen "
                + "fitness sin costo de fatiga, y ayudan a que las sesiones duras rindan.",
            rationale: "Reparte el resto de tu volumen entre los días fáciles, con un piso de 4 km "
                + "para que la salida valga la pena."
        )
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
        let days = clamp(input.config.daysPerWeek, 1, 7)
        let volumeTarget  = input.secondaries.first { $0.type == .weeklyVolume }?.targetValue
        let longRunTarget = input.secondaries.first { $0.type == .longRun }?.targetValue

        // Volumen de la semana. Sin historial (arranque en frío) usa un default por días disponibles.
        let base = input.currentWeeklyKm > 0 ? input.currentWeeklyKm : Double(days) * 5
        var weekKm = min(base * 1.08, volumeTarget ?? base * 1.08)
        weekKm = max(weekKm, base)                       // nunca por debajo del actual

        // Taper: última semana antes de la meta.
        let tapering = weeksLeft(input.primary.deadline, input.now).map { $0 <= 1 } ?? false
        if tapering { weekKm *= 0.6 }

        let structure = structure(for: days)             // ordenado, tirada larga al final
        let easyCount = structure.filter { $0 == .easy }.count

        // Tirada larga: progresa +1 km/sem hacia su target; acotada por la fracción base y por un
        // **máximo absoluto** (una tirada no crece sin límite aunque el volumen sea alto).
        let frac = longFraction(days: days)
        let longCeiling = min(weekKm * 0.6, maxLongKm)
        let progressed = input.currentLongRunKm.map { min($0 + 1, longRunTarget ?? .greatestFiniteMagnitude) }
        var longKm = clampD(progressed ?? weekKm * frac, weekKm * frac, longCeiling)

        // Sesiones de calidad con volumen **topado**: una serie es por repeticiones, no un balde de
        // kilómetros, así que el tope absoluto manda por encima de la fracción del volumen.
        let tempoKm     = structure.contains(.tempo)     ? min(weekKm * 0.20, maxTempoKm)     : 0
        let intervalsKm = structure.contains(.intervals) ? min(weekKm * 0.15, maxIntervalsKm) : 0

        // El resto del volumen lo absorben, en orden: los rodajes fáciles (la esponja natural) y
        // luego la tirada larga hasta su techo. Lo que aún NO quepa se reporta (faltan días para
        // tu volumen), en vez de inflar una sesión de calidad a un tamaño absurdo.
        var leftover = weekKm - longKm - tempoKm - intervalsKm
        let easyEach = easyCount > 0 ? clampD(max(0, leftover) / Double(easyCount), minEasyKm, longKm) : 0
        leftover -= easyEach * Double(easyCount)
        let addToLong = clampD(leftover, 0, longCeiling - longKm)
        longKm += addToLong
        leftover -= addToLong

        let note: String? = leftover > unfitThresholdKm
            ? "Tu volumen (~\(Goal.trim(weekKm)) km) no cabe sano en \(days) días: sube a "
                + "~\(suggestedDays(weekKm)) días para repartirlo en vez de meter sesiones enormes."
            : nil

        func km(for kind: PlannedWorkoutKind) -> Double {
            switch kind {
            case .longRun:   return round1(longKm)
            case .tempo:     return round1(tempoKm)
            case .intervals: return round1(intervalsKm)
            case .easy:      return round1(easyEach)
            }
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
            note: note,
            weekStart: input.weekStart
        )
    }

    // MARK: - Reglas (constantes calibrables)

    /// Estructura de la semana por días disponibles. La tirada larga siempre al final para que
    /// caiga en el día más tardío (típicamente fin de semana).
    private func structure(for days: Int) -> [PlannedWorkoutKind] {
        switch days {
        case 1:  return [.longRun]                                            // la sesión clave
        case 2:  return [.tempo, .longRun]
        case 3:  return [.intervals, .tempo, .longRun]
        case 4:  return [.intervals, .tempo, .easy, .longRun]
        case 5:  return [.intervals, .tempo, .easy, .easy, .longRun]
        case 6:  return [.intervals, .tempo, .easy, .easy, .easy, .longRun]
        default: return [.intervals, .tempo, .easy, .easy, .easy, .easy, .longRun]  // 7
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

    // Topes de sesión (km). Las de calidad no escalan con el volumen: son por repeticiones/ritmo.
    // ponytail: constantes globales; hazlas por distancia de meta (una larga de 21K ≠ de 42K) si hace falta.
    private var maxLongKm: Double      { 30 }
    private var maxTempoKm: Double     { 14 }
    private var maxIntervalsKm: Double { 9 }
    private var minEasyKm: Double      { 4 }
    /// Km sobrantes a partir de los cuales avisamos que el volumen no cabe en los días dados.
    private var unfitThresholdKm: Double { 5 }

    /// Días/semana sugeridos para repartir un volumen sano (~14 km por día como cota gruesa).
    private func suggestedDays(_ weekKm: Double) -> Int {
        clamp(Int((weekKm / 14).rounded(.up)), 2, 6)
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
        if count >= 7 { return Array(1...7) }            // toda la semana
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

        // Caso normal: 30 km / 3 días.
        let plan = gen(.init(
            primary: goal,
            config: PlanConfig(daysPerWeek: 3, preferredWeekdays: [3, 5, 7]),
            currentWeeklyKm: 30, currentLongRunKm: 12
        ))
        let kinds = Set(plan.days.map(\.kind))
        assert(kinds.isSuperset(of: [.longRun, .tempo, .intervals]),
               "3 días debe incluir tirada larga + tempo + series")
        let longKm = plan.days.first { $0.kind == .longRun }?.targetKm ?? 0
        assert(longKm == plan.days.compactMap(\.targetKm).max(),
               "la tirada larga debe ser el día más largo")
        assert(plan.days.map(\.weekday) == [3, 5, 7], "debe respetar los días preferidos")

        // Volumen alto en pocos días: las sesiones de calidad NO se disparan (topadas) y se avisa.
        let big = gen(.init(primary: goal, config: PlanConfig(daysPerWeek: 3),
                            currentWeeklyKm: 65, currentLongRunKm: 26))
        let series = big.days.first { $0.kind == .intervals }?.targetKm ?? 0
        let tempo  = big.days.first { $0.kind == .tempo }?.targetKm ?? 0
        assert(series <= 9.01, "series debe estar topada, no 18 km (\(Goal.trim(series)))")
        assert(tempo  <= 14.01, "tempo debe estar topado (\(Goal.trim(tempo)))")
        assert((big.days.compactMap(\.targetKm).max() ?? 0) <= 30.01, "ningún día pasa el tope de larga")
        assert(big.note != nil, "volumen alto en pocos días debe avisar subir días")

        // Todos los conteos de días (1–7) generan esa cantidad de sesiones, en días sin repetir.
        for d in 1...7 {
            let p = gen(.init(primary: goal, config: PlanConfig(daysPerWeek: d),
                              currentWeeklyKm: 30, currentLongRunKm: 12))
            assert(p.days.count == d, "\(d) días debe generar \(d) sesiones")
            assert(Set(p.days.map(\.weekday)).count == d, "\(d) días: sin repetir día de la semana")
        }

        return "OK · normal: larga \(Goal.trim(longKm)) km · "
             + "alto: series \(Goal.trim(series)) km, tempo \(Goal.trim(tempo)) km, aviso ✓"
    }
}
#endif
