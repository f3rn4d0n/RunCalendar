import Testing
@testable import RunCalendar

/// `WorkoutStructure`: los números que se le mandan al Apple Watch tienen que ser los mismos que
/// la tarjeta dice en prosa. La estructura es la fuente; los textos se derivan de ella.
@Suite("WorkoutStructure · el reloj y la tarjeta dicen lo mismo")
struct WorkoutStructureTests {

    private func guide(_ kind: PlannedWorkoutKind, km: Double) -> WorkoutGuide {
        DescribeWorkoutUseCase()(
            PlannedDay(weekday: 2, kind: kind, targetKm: km, label: "test", detail: "test")
        )
    }

    @Test("Las series estructuradas coinciden con el headline")
    func intervalsMatchHeadline() {
        // 4 km fuertes => repeticiones de 600 m (el corte de 800 m es > 4 km) => 7 × 600.
        let series = guide(.intervals, km: 4)
        #expect(series.structure.intervals?.reps == 7)
        #expect(series.structure.intervals?.repMeters == 600)
        #expect(series.headline == "7 × 600 m fuerte")
    }

    @Test("Arriba del corte las repeticiones son de 800 m")
    func longerIntervals() {
        let series = guide(.intervals, km: 4.8)
        #expect(series.structure.intervals?.repMeters == 800)
        #expect(series.headline == "6 × 800 m fuerte")
    }

    @Test("Si el reloj recupera 2 min, la tarjeta dice 2 min")
    func recoveryProseMatchesNumber() {
        let series = guide(.intervals, km: 4)
        #expect(series.structure.intervals?.recoverySeconds == 120)

        let block = series.steps.first { $0.label == "Bloque principal" }
        #expect(block?.detail.contains("2 min") == true)
        // Ya no es un rango: una sesión ejecutable se compromete con un número.
        #expect(block?.detail.contains("–") == false)
    }

    @Test("Repeticiones cortas, recuperación corta — y la prosa la sigue")
    func shortIntervalsShortRecovery() {
        let series = guide(.intervals, km: 2)
        #expect(series.structure.intervals?.repMeters == 400)
        #expect(series.structure.intervals?.recoverySeconds == 90)
        #expect(series.steps.first { $0.label == "Bloque principal" }?
            .detail.contains("90 s") == true)
    }

    @Test("Calentamiento y enfriamiento: números presentes y citados igual")
    func warmupAndCooldown() {
        let series = guide(.intervals, km: 4)
        #expect(series.structure.warmupMinutes == 12)
        #expect(series.structure.cooldownMinutes == 10)
        #expect(series.steps.first?.detail.contains("12 min") == true)
    }

    @Test("Las sesiones continuas llevan km exactos y ningún bloque de repeticiones",
          arguments: [PlannedWorkoutKind.tempo, .longRun, .easy])
    func steadySessions(kind: PlannedWorkoutKind) {
        let g = guide(kind, km: 12)
        #expect(g.structure.steadyKm == 12)
        #expect(g.structure.intervals == nil)
    }

    @Test("El tempo calienta y enfría; el fácil y la larga salen a correr y ya")
    func onlyTempoWarmsUp() {
        #expect(guide(.tempo, km: 12).structure.warmupMinutes == 10)
        #expect(guide(.easy, km: 8).structure.warmupMinutes == nil)
        #expect(guide(.longRun, km: 20).structure.cooldownMinutes == nil)
    }

    @Test("Toda sesión del plan tiene algo que ejecutar",
          arguments: PlannedWorkoutKind.allCases)
    func everySessionIsRunnable(kind: PlannedWorkoutKind) {
        // Si no, el botón de enviar al reloj no tendría qué mandar.
        let s = guide(kind, km: 6).structure
        #expect(s.intervals != nil || (s.steadyKm ?? 0) > 0)
    }
}
