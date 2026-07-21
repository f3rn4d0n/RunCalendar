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

/// Sugiere un plan desde el historial de carreras (sin IA, análogo a "Sugerir meta"): infiere
/// cuántos días/semana corres, en qué días, y un volumen objetivo (+20% en 8 semanas). Todo editable.
/// Usa solo carreras (no camina/senderismo). `nil` si no hay historial suficiente.
struct SuggestPlanUseCase: Sendable {
    func callAsFunction(runningSessions: [TrainingSession], now: Date = Date()) -> PlanSuggestion? {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -42, to: now) ?? now   // ~6 semanas
        let recent = runningSessions.filter { $0.completed && $0.date >= cutoff && $0.date <= now }
        guard recent.count >= 3 else { return nil }                          // mínimo para inferir

        // Agrupa por semana para promediar frecuencia y volumen sobre semanas activas.
        let byWeek = Dictionary(grouping: recent) {
            cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0.date)
        }
        let activeWeeks = max(1, byWeek.count)

        // Días/semana: promedio de días distintos que corres por semana activa.
        let distinctDaysPerWeek = byWeek.values.map { Set($0.map { cal.component(.weekday, from: $0.date) }).count }
        let avgDays = Double(distinctDaysPerWeek.reduce(0, +)) / Double(activeWeeks)
        let daysPerWeek = min(7, max(1, Int(avgDays.rounded())))

        // Días preferidos: los días de la semana en que más corres, tantos como daysPerWeek.
        let weekdayFreq = Dictionary(grouping: recent) { cal.component(.weekday, from: $0.date) }.mapValues(\.count)
        let preferred = weekdayFreq
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(daysPerWeek).map(\.key).sorted()

        // Volumen: promedio semanal (km) → meta +20% en 8 semanas (bajo el techo de ~10%/sem).
        let avgWeekly = byWeek.values.map { $0.compactMap(\.distanceKm).reduce(0, +) }.reduce(0, +) / Double(activeWeeks)
        guard avgWeekly > 0 else { return nil }
        let target = (avgWeekly * 1.2).rounded()
        let deadline = cal.date(byAdding: .day, value: 56, to: now)

        let dayNames = preferred.map { cal.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
        let rationale = "Corres ~\(daysPerWeek) días/semana (\(dayNames)) y ~\(Goal.trim(avgWeekly)) km. "
            + "Meta sugerida: \(Goal.trim(target)) km/sem en ~8 semanas (+20%). Todo editable."

        return PlanSuggestion(
            config: PlanConfig(daysPerWeek: daysPerWeek, preferredWeekdays: Array(preferred)),
            weeklyVolumeTarget: target,
            deadline: deadline,
            rationale: rationale
        )
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

        let structure = structure(for: days)             // alternado duro/fácil, tirada larga al final

        // Tirada larga: progresa +1 km/sem hacia su target; acotada por la fracción base y por un
        // **máximo absoluto** (una tirada no crece sin límite aunque el volumen sea alto).
        let frac = longFraction(days: days)
        let longCeiling = min(weekKm * 0.6, maxLongKm)
        let progressed = input.currentLongRunKm.map { min($0 + 1, longRunTarget ?? .greatestFiniteMagnitude) }
        let longKm = round1(clampD(progressed ?? weekKm * frac, weekKm * frac, longCeiling))

        // El resto del volumen se **reparte** entre las demás sesiones por pesos, con tope por tipo
        // (series/tempo no escalan). Así, a más días la misma carga se divide en sesiones más cortas
        // —en vez de apilar rodajes con un piso fijo— y lo que no quepa se reporta (faltan días).
        let others = structure.filter { $0 != .longRun }
        let (othersKm, unfit) = allocate(others, budget: weekKm - longKm, longKm: longKm)
        var othersIter = othersKm.makeIterator()
        let kmByIndex = structure.map { $0 == .longRun ? longKm : round1(othersIter.next() ?? 0) }

        // Asigna días de la semana: preferidos (ordenados) o un reparto por defecto espaciado.
        let weekdays = weekdays(for: input.config, count: structure.count)
        let planned: [PlannedDay] = zip(weekdays, zip(structure, kmByIndex)).map { weekday, pair in
            PlannedDay(weekday: weekday, kind: pair.0, targetKm: pair.1,
                       label: label(pair.0, km: pair.1), detail: detail(pair.0))
        }

        let note = planNote(planned: planned, weekKm: weekKm, days: days, unfit: unfit)

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

    /// Estructura de la semana por días disponibles. Días duros (series/tempo) **separados por un
    /// rodaje fácil** cuando hay días para ello, y la tirada larga al final (día más tardío).
    private func structure(for days: Int) -> [PlannedWorkoutKind] {
        switch days {
        case 1:  return [.longRun]                                            // la sesión clave
        case 2:  return [.tempo, .longRun]
        case 3:  return [.intervals, .tempo, .longRun]
        case 4:  return [.intervals, .easy, .tempo, .longRun]
        case 5:  return [.intervals, .easy, .tempo, .easy, .longRun]
        case 6:  return [.intervals, .easy, .tempo, .easy, .easy, .longRun]
        default: return [.intervals, .easy, .tempo, .easy, .easy, .easy, .longRun]  // 7
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

    /// Días/semana sugeridos para repartir un volumen alto sin sesiones enormes (~14 km/día).
    private func suggestedDays(_ weekKm: Double) -> Int {
        clamp(Int((weekKm / 14).rounded(.up)), 1, 7)
    }

    /// Días máximos que mantienen sesiones de tamaño útil para un volumen bajo (~5 km/día).
    private func suggestedDaysLow(_ weekKm: Double) -> Int {
        clamp(Int((weekKm / (minEasyKm + 1)).rounded(.down)), 1, 7)
    }

    /// Peso relativo de volumen por tipo (la tirada larga se calcula aparte).
    private func roleWeight(_ kind: PlannedWorkoutKind) -> Double {
        switch kind {
        case .tempo:     return 1.3
        case .intervals: return 1.0
        case .easy:      return 1.3
        case .longRun:   return 0
        }
    }

    private func capFor(_ kind: PlannedWorkoutKind, longKm: Double) -> Double {
        switch kind {
        case .tempo:     return maxTempoKm
        case .intervals: return maxIntervalsKm
        case .easy:      return longKm      // un rodaje fácil nunca más largo que la tirada larga
        case .longRun:   return .greatestFiniteMagnitude
        }
    }

    /// Reparte `budget` km entre `kinds` por pesos, respetando el tope de cada tipo (water-filling):
    /// lo que rebasa un tope se re-reparte entre los que aún tienen cupo. Devuelve los km por índice
    /// y el sobrante que no cupo (topes saturados ⇒ faltan días para el volumen).
    private func allocate(_ kinds: [PlannedWorkoutKind], budget: Double, longKm: Double) -> ([Double], Double) {
        var km = [Double](repeating: 0, count: kinds.count)
        guard !kinds.isEmpty else { return (km, max(0, budget)) }
        var capped = [Bool](repeating: false, count: kinds.count)
        var pool = max(0, budget)
        for _ in 0...kinds.count {
            let active = kinds.indices.filter { !capped[$0] }
            let weightSum = active.reduce(0.0) { $0 + roleWeight(kinds[$1]) }
            guard pool > 0.01, weightSum > 0 else { break }
            let poolStart = pool
            var cappedAny = false
            for i in active {
                let share = poolStart * roleWeight(kinds[i]) / weightSum
                let cap = capFor(kinds[i], longKm: longKm)
                if km[i] + share >= cap - 1e-9 {
                    pool -= (cap - km[i]); km[i] = cap; capped[i] = true; cappedAny = true
                }
            }
            if !cappedAny {
                for i in active { km[i] += poolStart * roleWeight(kinds[i]) / weightSum }
                pool = 0; break
            }
        }
        return (km, pool)
    }

    /// Aviso del coach, por prioridad: (1) el volumen no cabe → faltan días; (2) demasiados días →
    /// sesiones muy cortas; (3) sesiones exigentes en días seguidos (por los días elegidos).
    private func planNote(planned: [PlannedDay], weekKm: Double, days: Int, unfit: Double) -> String? {
        if unfit > unfitThresholdKm {
            return "Tu volumen (~\(Goal.trim(weekKm)) km) no cabe sano en \(days) días: sube a "
                + "~\(suggestedDays(weekKm)) días para repartirlo en vez de meter sesiones enormes."
        }
        let shortest = planned.compactMap(\.targetKm).min() ?? 0
        if days > 1, shortest < 3 {
            return "Con \(days) días algunas sesiones quedan muy cortas para tu volumen "
                + "(~\(Goal.trim(weekKm)) km). Da para ~\(suggestedDaysLow(weekKm)) días; súbelo o baja días."
        }
        let demanding = planned.filter { $0.kind.isHard || $0.kind == .longRun }.map(\.weekday).sorted()
        if zip(demanding, demanding.dropFirst()).contains(where: { $1 - $0 == 1 }) {
            return "Tienes sesiones exigentes en días seguidos. Deja un día fácil o de descanso "
                + "entre ellas si puedes (ajusta tus días preferidos)."
        }
        return nil
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

        // Redistribución: a igual volumen, más días ⇒ misma carga repartida en sesiones más cortas
        // (no se apilan rodajes con piso fijo).
        let p3 = gen(.init(primary: goal, config: PlanConfig(daysPerWeek: 3),
                           currentWeeklyKm: 40, currentLongRunKm: 14))
        let p5 = gen(.init(primary: goal, config: PlanConfig(daysPerWeek: 5),
                           currentWeeklyKm: 40, currentLongRunKm: 14))
        assert(abs(p3.totalKm - p5.totalKm) <= 2, "misma carga semanal con distinto nº de días")
        let tempo3 = p3.days.first { $0.kind == .tempo }?.targetKm ?? 0
        let tempo5 = p5.days.first { $0.kind == .tempo }?.targetKm ?? 0
        assert(tempo5 <= tempo3 + 0.01, "más días ⇒ sesiones de calidad no más largas")

        return "OK · normal: larga \(Goal.trim(longKm)) km · "
             + "alto: series \(Goal.trim(series)) km, tempo \(Goal.trim(tempo)) km, aviso ✓"
    }
}
#endif
