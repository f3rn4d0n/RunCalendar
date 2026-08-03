import HealthKit
import WorkoutKit

/// Traduce una sesión del plan a un entrenamiento de Apple Watch (WorkoutKit).
///
/// **Aquí no se programa ningún aviso.** Se arma la estructura (calentamiento · bloques ·
/// enfriamiento) y la app Entrenamiento del reloj es la que da el háptico y la voz al cerrar cada
/// repetición y al cambiar de paso, y la que avanza sola. Por eso esto no necesita un target de
/// watchOS: el motor ya viene en el reloj.
///
/// `// ponytail:` sin alertas de ritmo (`SpeedRangeAlert`) a propósito. Pedirían convertir un PR de
/// 5K a un rango de velocidad, y el plan es cualitativo por principio ("nunca un dato inventado").
/// Se agregan cuando exista un PR fiable del que derivarlas.
enum WatchWorkoutBuilder {

    /// `nil` si la sesión no tiene nada que ejecutar, o si el dispositivo no puede tener un reloj
    /// emparejado (Mac): así la UI solo pregunta por el plan y el botón desaparece solo.
    static func plan(for guide: WorkoutGuide, displayName: String) -> WorkoutPlan? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let structure = guide.structure
        var blocks: [IntervalBlock] = []

        if let spec = structure.intervals {
            blocks.append(IntervalBlock(
                steps: [
                    IntervalStep(.work, goal: {
                        switch spec.rep {
                        case .meters(let m):  return .distance(m, .meters)
                        case .seconds(let s): return .time(s, .seconds)
                        }
                    }()),
                    IntervalStep(.recovery, goal: .time(spec.recoverySeconds, .seconds))
                ],
                iterations: spec.reps
            ))
        }

        if let km = structure.steadyKm, km > 0 {
            blocks.append(IntervalBlock(
                steps: [IntervalStep(.work, goal: .distance(km, .kilometers))]
            ))
        }

        guard !blocks.isEmpty else { return nil }

        return WorkoutPlan(.custom(CustomWorkout(
            activity: .running,
            location: .outdoor,
            displayName: displayName,
            warmup: structure.warmupMinutes.map { WorkoutStep(goal: .time($0, .minutes)) },
            blocks: blocks,
            cooldown: structure.cooldownMinutes.map { WorkoutStep(goal: .time($0, .minutes)) }
        )))
    }
}
