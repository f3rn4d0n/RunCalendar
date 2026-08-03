import Foundation
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

/// El estímulo de calidad rota por semana en vez de repetir siempre la misma sesión.
@Suite("QualityEmphasis · variar el estímulo de la semana")
struct QualityEmphasisTests {

    private let describe = DescribeWorkoutUseCase()
    private let engine = GeneratePlanUseCase()

    private func day(_ emphasis: QualityEmphasis, km: Double = 6) -> PlannedDay {
        PlannedDay(weekday: 3, kind: .intervals, targetKm: km,
                   label: "Series", detail: "", emphasis: emphasis)
    }

    private func plan(weeksToGoal: Int) -> TrainingPlan {
        engine(GeneratePlanUseCase.Input(
            primary: Goal(type: .raceTime, targetValue: 7200,
                          deadline: Date().addingTimeInterval(Double(weeksToGoal) * 7 * 86400 + 86400)),
            config: PlanConfig(daysPerWeek: 4),
            currentWeeklyKm: 40
        ))
    }

    @Test("Cada énfasis produce una sesión distinta, no la misma con otro nombre")
    func eachEmphasisIsItsOwnSession() {
        let headlines = QualityEmphasis.allCases.map { describe(day($0)).headline }
        #expect(Set(headlines).count == QualityEmphasis.allCases.count, "\(headlines)")
    }

    @Test("Las repeticiones largas son más largas y con más recuperación que las cortas")
    func longRepsAreLongerAndRestMore() {
        let cortas = describe(day(.shortReps)).structure.intervals
        let largas = describe(day(.longReps)).structure.intervals
        #expect((largas?.repMeters ?? 0) > (cortas?.repMeters ?? 0))
        #expect((largas?.recoverySeconds ?? 0) > (cortas?.recoverySeconds ?? 0))
        #expect((largas?.reps ?? 99) < (cortas?.reps ?? 0), "menos repeticiones, más largas")
    }

    @Test("Cuestas y fartlek se miden en tiempo, no en metros")
    func timeBasedSessionsDoNotInventDistances() {
        // Nadie corre "400 m" en un fartlek: se corre un minuto fuerte. Modelarlo en metros
        // obligaría a inventar una distancia que el atleta no va a medir.
        for emphasis in [QualityEmphasis.hills, .fartlek] {
            guard case .seconds = describe(day(emphasis)).structure.intervals?.rep else {
                Issue.record("\(emphasis) debería medirse en tiempo")
                return
            }
            #expect(describe(day(emphasis)).structure.intervals?.repMeters == nil)
        }
    }

    @Test("El fartlek dice que está por disfrute, no que adapte más")
    func fartlekIsHonestAboutWhyItExists() {
        // Es el mismo estímulo que las series cortas. Venderlo como fisiología sería el mito de la
        // "confusión muscular"; el motivo real —que apetezca salir— es legítimo y distinto.
        let purpose = describe(day(.fartlek)).purpose
        #expect(purpose.contains("mismo estímulo"))
        #expect(purpose.lowercased().contains("apetezca") || purpose.lowercased().contains("disfrut"))
    }

    @Test("El reloj sabe ejecutar las dos formas de repetición", arguments: QualityEmphasis.allCases)
    func watchHandlesBothRepKinds(emphasis: QualityEmphasis) {
        // En simulador `WatchWorkoutBuilder` devuelve nil (no hay datos de salud), así que lo que se
        // fija aquí es que la estructura esté completa para poder construirlo.
        let structure = describe(day(emphasis)).structure
        #expect(structure.intervals?.reps ?? 0 > 0)
        #expect(structure.intervals?.recoverySeconds ?? 0 > 0)
    }

    @Test("Cerca de la meta todo pasa a ritmo de carrera")
    func specificityNearTheGoal() {
        for weeks in 0...3 {
            let series = plan(weeksToGoal: weeks).days.first { $0.kind == .intervals }
            #expect(series?.emphasis == .racePace, "a \(weeks) semanas debería ser específico")
        }
    }

    @Test("Lejos de la meta el estímulo rota entre semanas")
    func emphasisRotatesAcrossWeeks() {
        let porSemana = (4...11).map { plan(weeksToGoal: $0).days.first { $0.kind == .intervals }?.emphasis }
        #expect(Set(porSemana.compactMap { $0 }).count >= 3, "apenas rota: \(porSemana)")
        #expect(!porSemana.contains(.racePace), "el ritmo de carrera se reserva para el final")
    }

    @Test("La vista previa dice qué sesión de calidad toca, no solo «Series»")
    func previewNamesTheFocus() {
        // Desde que el estímulo rota, "Series" a secas ya no distingue entre unas cortas, unas
        // cuestas y un fartlek — que es justo lo que la rotación viene a diferenciar.
        for weeks in [2, 4, 5, 6, 7] {
            guard let series = plan(weeksToGoal: weeks).days.first(where: { $0.kind == .intervals }),
                  let emphasis = series.emphasis else { continue }
            #expect(series.label.hasPrefix(emphasis.displayName), "label: \(series.label)")
            // "fuertes" porque `targetKm` en una sesión por repeticiones es solo la parte fuerte;
            // el calentamiento y el enfriamiento están en el detalle.
            #expect(series.label.contains("fuertes"))
        }
    }

    @Test("Cada enfoque explica en una línea de qué va, sin repetir la misma frase")
    func eachFocusHasItsOwnOneLiner() {
        let details = [2, 4, 5, 6, 7].compactMap { weeks in
            plan(weeksToGoal: weeks).days.first { $0.kind == .intervals }?.detail
        }
        #expect(Set(details).count >= 3, "la línea de apoyo no cambia con el enfoque: \(details)")
    }

    @Test("Los demás tipos se siguen nombrando por su tipo")
    func otherKindsKeepTheirName() {
        // Homologado: todos los tipos dicen su enfoque en el mismo sitio y con el mismo formato.
        for day in plan(weeksToGoal: 8).days where day.kind != .intervals && day.kind != .race {
            #expect(day.label.hasPrefix(day.kind.rawValue), "label: \(day.label)")
        }
    }

    @Test("Los días que no son series no llevan énfasis")
    func onlyIntervalsCarryEmphasis() {
        for day in plan(weeksToGoal: 8).days where day.kind != .intervals {
            #expect(day.emphasis == nil, "\(day.kind.rawValue) no es una sesión de calidad variable")
        }
    }
}
