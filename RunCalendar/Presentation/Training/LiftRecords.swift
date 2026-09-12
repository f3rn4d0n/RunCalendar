import Foundation

/// Un esfuerzo de una serie de fuerza, venga de donde venga: embebida en un WOD o registrada
/// suelta. `origin` guarda los ids reales para poder editar el esfuerzo sin importar cuál fue.
struct LiftEffort: Identifiable, LiftPerformance {
    enum Origin {
        case session(sessionID: String, setID: String)
        case entry(entryID: String)
    }

    let id: String
    let date: Date
    /// Título del WOD, o el nombre del ejercicio si el esfuerzo es un registro suelto.
    let label: String
    let exercise: StrengthExercise
    let weightKg: Double
    let reps: Int
    let origin: Origin
}

/// Récord de un ejercicio: mejor esfuerzo y el historial (un esfuerzo por sesión/registro).
struct LiftRecord: Identifiable {
    let exercise: StrengthExercise
    let best: LiftEffort
    let history: [LiftEffort]   // cronológico ascendente
    var id: String { exercise.id }
}

/// Calcula los récords de levantamiento agrupando por ejercicio, fusionando las dos fuentes de
/// series: las embebidas en un WOD (`TrainingSession.sets`) y las registradas sueltas
/// (`LiftEntry`). Un PR es un PR sin importar de cuál vino.
///
/// Rankea por **1RM estimado** en carga externa (así 100 kg × 3 compite con 110 kg × 1, igual que
/// `PersonalRecords` rankea por ritmo y no por tiempo bruto) y por **repeticiones** en peso
/// corporal (ahí no hay 1RM que estimar sin inventar el peso del atleta).
enum LiftRecords {
    /// ponytail: 12 reps, sin calibrar. Epley sobreestima fuerte arriba de ~10–12 y un AMRAP de
    /// 20 fabricaría un PR falso. Esas series siguen registradas y cuentan para el historial
    /// (`history(for:)`), solo no compiten por récord.
    static let maxRepsForEstimate = 12

    /// Récords: agrupa por ejercicio, aplica el tope de reps y deduplica por sesión/registro.
    static func compute(sessions: [TrainingSession], entries: [LiftEntry] = []) -> [LiftRecord] {
        buildRecords(from: efforts(sessions: sessions, entries: entries).filter(isEligibleForRecord))
    }

    /// Historial completo de un ejercicio, para el detalle: sin el tope de 12 reps (una serie de
    /// más repeticiones sigue siendo un resultado real, solo no compite por récord). Un esfuerzo
    /// por sesión/registro, orden cronológico ascendente.
    static func history(for exercise: StrengthExercise, sessions: [TrainingSession],
                        entries: [LiftEntry] = []) -> [LiftEffort] {
        let filtered = efforts(sessions: sessions, entries: entries).filter { $0.exercise == exercise }
        return dedupByOrigin(filtered).sorted { $0.date < $1.date }
    }

    // MARK: - Privado

    /// Todos los esfuerzos de las dos fuentes, sin filtrar ni deduplicar todavía. Una sesión
    /// planeada a futuro con series escritas no es un levantamiento real, por eso solo cuentan
    /// las completadas.
    private static func efforts(sessions: [TrainingSession], entries: [LiftEntry]) -> [LiftEffort] {
        let fromSessions = sessions.filter(\.completed).flatMap { session in
            session.sets.filter { $0.reps > 0 }.map { set in
                LiftEffort(id: "s-\(session.id)-\(set.id)", date: session.date, label: session.title,
                          exercise: set.exercise, weightKg: set.weightKg, reps: set.reps,
                          origin: .session(sessionID: session.id, setID: set.id))
            }
        }
        let fromEntries = entries.filter { $0.reps > 0 }.map { entry in
            LiftEffort(id: "e-\(entry.id)", date: entry.date, label: entry.exercise.displayName,
                      exercise: entry.exercise, weightKg: entry.weightKg, reps: entry.reps,
                      origin: .entry(entryID: entry.id))
        }
        return fromSessions + fromEntries
    }

    /// Series con datos usables para el récord. Sin tope de reps en peso corporal: una serie de
    /// 30 dominadas *es* el récord, no una serie descartada.
    private static func isEligibleForRecord(_ effort: LiftEffort) -> Bool {
        guard effort.exercise.loadStyle == .external else { return true }
        return effort.reps <= maxRepsForEstimate && effort.estimatedOneRM != nil
    }

    /// Un esfuerzo por sesión (su mejor serie para ese ejercicio) o por registro suelto (ya es
    /// atómico, deduplicar consigo mismo no hace nada).
    private static func dedupByOrigin(_ efforts: [LiftEffort]) -> [LiftEffort] {
        let grouped = Dictionary(grouping: efforts) { effort -> String in
            switch effort.origin {
            case .session(let sessionID, _): return "s-\(sessionID)-\(effort.exercise.id)"
            case .entry(let entryID): return "e-\(entryID)"
            }
        }
        return grouped.values.compactMap { $0.max(by: isWorse) }
    }

    private static func buildRecords(from efforts: [LiftEffort]) -> [LiftRecord] {
        let byExercise = Dictionary(grouping: efforts) { $0.exercise }
        // En el orden del catálogo, no el de aparición: nada de secciones desordenadas.
        return StrengthExercise.allCases.compactMap { exercise -> LiftRecord? in
            guard let group = byExercise[exercise] else { return nil }
            let history = dedupByOrigin(group).sorted { $0.date < $1.date }
            guard let best = history.max(by: isWorse) else { return nil }
            return LiftRecord(exercise: exercise, best: best, history: history)
        }
    }

    /// Orden ascendente: 1RM estimado en carga externa; (reps, lastre) en peso corporal, para que
    /// más repeticiones siempre gane y el lastre solo desempate a igualdad de reps.
    private static func isWorse(_ a: LiftEffort, than b: LiftEffort) -> Bool {
        switch a.exercise.loadStyle {
        case .external:
            return (a.estimatedOneRM ?? 0) < (b.estimatedOneRM ?? 0)
        case .bodyweight:
            return (a.reps, a.weightKg) < (b.reps, b.weightKg)
        }
    }
}
