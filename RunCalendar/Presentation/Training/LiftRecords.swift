import Foundation

/// Un esfuerzo de una serie de fuerza, con la sesión que lo contiene.
struct LiftEffort: Identifiable {
    let id: String
    let date: Date
    let sessionTitle: String
    let sessionID: String
    let set: StrengthSet
}

/// Récord de un ejercicio: mejor esfuerzo y el historial (un esfuerzo por sesión).
struct LiftRecord: Identifiable {
    let exercise: StrengthExercise
    let best: LiftEffort
    let history: [LiftEffort]   // cronológico ascendente
    var id: String { exercise.id }
}

/// Calcula los récords de levantamiento agrupando por ejercicio. Análogo exacto de
/// `PersonalRecords`, que rankea por **ritmo** y no por tiempo bruto para que sea justo comparar
/// esfuerzos distintos: aquí se rankea por **1RM estimado** en carga externa (así 100 kg × 3
/// compite con 110 kg × 1) y por **repeticiones** en peso corporal (ahí no hay 1RM que estimar
/// sin inventar el peso del atleta).
enum LiftRecords {
    /// ponytail: 12 reps, sin calibrar. Epley sobreestima fuerte arriba de ~10–12 y un AMRAP de
    /// 20 fabricaría un PR falso. Esas series siguen registradas y cuentan para el volumen de la
    /// sesión, solo no compiten por récord.
    static let maxRepsForEstimate = 12

    static func compute(sessions: [TrainingSession]) -> [LiftRecord] {
        // Una sesión planeada a futuro con series escritas no es un levantamiento real.
        let efforts = sessions.filter(\.completed).flatMap { session in
            session.sets.filter(isEligible).map { set in
                LiftEffort(id: "\(session.id)-\(set.id)", date: session.date,
                          sessionTitle: session.title, sessionID: session.id, set: set)
            }
        }
        let byExercise = Dictionary(grouping: efforts) { $0.set.exercise }

        // En el orden del catálogo, no el de aparición: nada de secciones desordenadas.
        return StrengthExercise.allCases.compactMap { exercise -> LiftRecord? in
            guard let group = byExercise[exercise] else { return nil }

            // Un esfuerzo por sesión —el mejor de cada una—: cinco series de calentamiento no
            // son cinco récords, y la progresión se vuelve ilegible si lo son.
            let bestPerSession = Dictionary(grouping: group) { $0.sessionID }
                .values.compactMap { $0.max(by: isWorse) }
            guard let best = bestPerSession.max(by: isWorse) else { return nil }

            return LiftRecord(exercise: exercise, best: best,
                              history: bestPerSession.sorted { $0.date < $1.date })
        }
    }

    /// Series con datos usables. Sin tope de reps en peso corporal: una serie de 30 dominadas
    /// *es* el récord, no una serie descartada.
    private static func isEligible(_ set: StrengthSet) -> Bool {
        guard set.reps > 0 else { return false }
        if set.exercise.loadStyle == .external {
            return set.reps <= maxRepsForEstimate && set.estimatedOneRM != nil
        }
        return true
    }

    /// Orden ascendente: 1RM estimado en carga externa; (reps, lastre) en peso corporal, para que
    /// más repeticiones siempre gane y el lastre solo desempate a igualdad de reps.
    private static func isWorse(_ a: LiftEffort, than b: LiftEffort) -> Bool {
        switch a.set.exercise.loadStyle {
        case .external:
            return (a.set.estimatedOneRM ?? 0) < (b.set.estimatedOneRM ?? 0)
        case .bodyweight:
            return (a.set.reps, a.set.weightKg) < (b.set.reps, b.set.weightKg)
        }
    }
}
