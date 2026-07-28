// Check de WorkoutStructure: que los números que se le mandan al Apple Watch sean los mismos que
// la tarjeta dice en prosa. Compila contra los archivos reales (no duplica la lógica) y no
// necesita simulador ni target de tests. Desde la raíz del repo:
//
//   swiftc RunCalendar/Domain/Entities/TrainingPlan.swift RunCalendar/Domain/Entities/Goal.swift \
//     RunCalendar/Domain/Entities/Campaign.swift RunCalendar/Domain/Entities/Race.swift \
//     RunCalendar/Domain/UseCases/PlanUseCases.swift \
//     Scripts/check-workout-structure.swift -module-name check -o /tmp/check-structure \
//     && /tmp/check-structure
//
// Sin -O a propósito: en release los `assert` se compilan fuera y el check no verificaría nada.

import Foundation

@main struct CheckWorkoutStructure {

    static func guide(_ kind: PlannedWorkoutKind, km: Double) -> WorkoutGuide {
        DescribeWorkoutUseCase()(
            PlannedDay(weekday: 2, kind: kind, targetKm: km, label: "test", detail: "test")
        )
    }

    static func main() {
        // 1) Series: el bloque estructurado coincide con el headline en prosa.
        //    4 km fuertes => repeticiones de 600 m (el corte de 800 m es > 4 km) => 7 × 600.
        let series = guide(.intervals, km: 4)
        guard let spec = series.structure.intervals else {
            fatalError("las series deben traer bloque de repeticiones")
        }
        assert(spec.reps == 7, "reps: \(spec.reps)")
        assert(spec.repMeters == 600, "metros por rep: \(spec.repMeters)")
        assert(series.headline == "7 × 600 m fuerte", "headline: \(series.headline)")

        // 1b) Arriba del corte sí son de 800 m — el caso del ejemplo del atleta.
        let largas = guide(.intervals, km: 4.8)
        assert(largas.structure.intervals?.repMeters == 800, "rep larga")
        assert(largas.headline == "6 × 800 m fuerte", "headline: \(largas.headline)")

        // 2) La prosa se deriva de los números: si el reloj hace 2 min, la tarjeta dice 2 min.
        assert(spec.recoverySeconds == 120, "recuperación: \(spec.recoverySeconds)")
        let block = series.steps.first { $0.label == "Bloque principal" }!
        assert(block.detail.contains("2 min"), "la prosa no cita la recuperación real: \(block.detail)")
        assert(!block.detail.contains("–"), "la recuperación ya no debe ser un rango: \(block.detail)")

        // 3) Repeticiones cortas => recuperación corta, y la prosa la sigue.
        let cortas = guide(.intervals, km: 2)
        assert(cortas.structure.intervals?.repMeters == 400, "rep corta")
        assert(cortas.structure.intervals?.recoverySeconds == 90, "recuperación corta")
        assert(cortas.steps.first { $0.label == "Bloque principal" }!.detail.contains("90 s"))

        // 4) Calentamiento y enfriamiento: números presentes y citados igual en la prosa.
        assert(series.structure.warmupMinutes == 12, "calentamiento")
        assert(series.structure.cooldownMinutes == 10, "enfriamiento")
        assert(series.steps.first!.detail.contains("12 min"), "la prosa del calentamiento")

        // 5) Sesiones continuas: km exactos, sin bloque de repeticiones.
        for kind in [PlannedWorkoutKind.tempo, .longRun, .easy] {
            let g = guide(kind, km: 12)
            assert(g.structure.steadyKm == 12, "\(kind) km: \(String(describing: g.structure.steadyKm))")
            assert(g.structure.intervals == nil, "\(kind) no lleva repeticiones")
        }

        // 6) El tempo calienta y enfría; el rodaje fácil y la larga salen a correr y ya.
        assert(guide(.tempo, km: 12).structure.warmupMinutes == 10, "el tempo calienta")
        assert(guide(.easy, km: 8).structure.warmupMinutes == nil, "el fácil no calienta aparte")
        assert(guide(.longRun, km: 20).structure.cooldownMinutes == nil, "la larga no enfría aparte")

        // 7) Toda sesión del plan tiene algo que ejecutar (si no, el botón del reloj no sirve).
        for kind in PlannedWorkoutKind.allCases {
            let s = guide(kind, km: 6).structure
            assert(s.intervals != nil || (s.steadyKm ?? 0) > 0, "\(kind) sin nada que ejecutar")
        }

        print("check-workout-structure: OK")
    }
}
