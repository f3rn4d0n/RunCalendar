import Foundation
import Testing
@testable import RunCalendar

/// El motor del plan (Fase 3). Determinista y sin IA, así que se puede fijar por **invariantes**:
/// el 80/20, el techo de progresión, la tirada larga como día más largo, el taper.
///
/// Se prueban las reglas, no los números exactos: las constantes están sin calibrar a propósito
/// (ver *Umbrales sin calibrar* en `docs/pendientes.md`) y fijarlas cementaría valores que nadie
/// ha comprobado contra datos reales.
@Suite("GeneratePlanUseCase · el motor de la semana")
struct GeneratePlanTests {

    private let engine = GeneratePlanUseCase()

    private func goal(_ type: GoalType, _ target: Double, deadline: Date? = nil) -> Goal {
        Goal(type: type, targetValue: target, deadline: deadline)
    }

    private func plan(days: Int, weeklyKm: Double, longRunKm: Double? = nil,
                      secondaries: [Goal] = [], deadline: Date? = nil) -> TrainingPlan {
        engine(GeneratePlanUseCase.Input(
            primary: goal(.raceTime, 7200, deadline: deadline),
            secondaries: secondaries,
            config: PlanConfig(daysPerWeek: days),
            currentWeeklyKm: weeklyKm,
            currentLongRunKm: longRunKm
        ))
    }

    @Test("Genera tantas sesiones como días pida la config", arguments: 1...7)
    func honoursDaysPerWeek(days: Int) {
        #expect(plan(days: days, weeklyKm: 30).days.count == days)
    }

    @Test("Con 3 días la semana es series + tempo + tirada larga")
    func threeDayStructure() {
        let kinds = plan(days: 3, weeklyKm: 30).days.map(\.kind)
        #expect(Set(kinds) == [.intervals, .tempo, .longRun])
    }

    @Test("Los días duros no se encadenan: llevan un fácil en medio", arguments: 4...7)
    func hardDaysAreSeparated(days: Int) {
        let kinds = plan(days: days, weeklyKm: 40).days.map(\.kind)
        for (a, b) in zip(kinds, kinds.dropFirst()) {
            #expect(!(a.isHard && b.isHard), "\(a) seguido de \(b) encadena intensidad")
        }
    }

    @Test("La tirada larga es siempre el día más largo de la semana", arguments: 2...7)
    func longRunIsTheLongestDay(days: Int) {
        let week = plan(days: days, weeklyKm: 40, longRunKm: 12).days
        let long = week.first { $0.kind == .longRun }?.targetKm ?? 0
        for day in week where day.kind != .longRun {
            #expect((day.targetKm ?? 0) <= long)
        }
    }

    @Test("80/20: las sesiones de calidad no se llevan el grueso del volumen")
    func eightyTwentySplit() {
        let week = plan(days: 5, weeklyKm: 50).days
        let total = week.compactMap(\.targetKm).reduce(0, +)
        let hard = week.filter { $0.kind.isHard }.compactMap(\.targetKm).reduce(0, +)
        #expect(hard / total < 0.5, "la calidad se llevó \(hard) de \(total) km")
    }

    @Test("El volumen no salta más del ~10% respecto al actual")
    func volumeProgressionIsCapped() {
        let current = 40.0
        let total = plan(days: 5, weeklyKm: current,
                         secondaries: [goal(.weeklyVolume, 100)])   // meta muy por encima
            .days.compactMap(\.targetKm).reduce(0, +)
        #expect(total <= current * 1.1, "saltó a \(total) desde \(current)")
        #expect(total >= current, "nunca por debajo del volumen actual")
    }

    @Test("El volumen nunca baja del actual aunque la meta sea menor")
    func neverBelowCurrentVolume() {
        let total = plan(days: 4, weeklyKm: 40, secondaries: [goal(.weeklyVolume, 20)])
            .days.compactMap(\.targetKm).reduce(0, +)
        #expect(total >= 40)
    }

    @Test("Las sesiones de calidad están topadas: una serie es por repeticiones, no un balde de km")
    func qualitySessionsAreCapped() {
        // Volumen alto a propósito: si no hubiera tope, series y tempo crecerían con él.
        let week = plan(days: 5, weeklyKm: 120).days
        for day in week {
            switch day.kind {
            case .intervals: #expect((day.targetKm ?? 0) <= 9)
            case .tempo:     #expect((day.targetKm ?? 0) <= 14)
            case .longRun:   #expect((day.targetKm ?? 0) <= 30)
            case .easy:      break
            case .race:      break   // sin carreras en esta entrada; su distancia es un hecho
            }
        }
    }

    @Test("Arranque en frío (sin historial) genera una semana usable igual")
    func coldStart() {
        let week = plan(days: 3, weeklyKm: 0).days
        #expect(week.count == 3)
        #expect(week.allSatisfy { ($0.targetKm ?? 0) > 0 })
    }

    // MARK: - Taper

    /// Meta a `days` días vista, para caer en la ventana de afinamiento que se quiera probar.
    private func inDays(_ days: Int) -> Date {
        Date().addingTimeInterval(60 * 60 * 24 * Double(days))
    }

    private func kmByKind(_ week: TrainingPlan) -> [PlannedWorkoutKind: Double] {
        Dictionary(week.days.map { ($0.kind, $0.targetKm ?? 0) }, uniquingKeysWith: +)
    }

    @Test("La última semana antes de la meta hace taper")
    func tapersBeforeTheRace() {
        let normal = plan(days: 4, weeklyKm: 40).totalKm
        let taper = plan(days: 4, weeklyKm: 40, deadline: inDays(4)).totalKm
        #expect(taper < normal, "taper \(taper) vs. semana normal \(normal)")
    }

    @Test("El taper dura ~2 semanas, no una")
    func taperLastsTwoWeeks() {
        let normal = plan(days: 4, weeklyKm: 40).totalKm
        #expect(plan(days: 4, weeklyKm: 40, deadline: inDays(10)).totalKm < normal,
                "la penúltima semana también afina")
        #expect(plan(days: 4, weeklyKm: 40, deadline: inDays(21)).totalKm == normal,
                "a 3 semanas todavía se entrena normal")
    }

    @Test("El taper es progresivo: la semana de la carrera recorta más que la penúltima")
    func taperIsProgressive() {
        let penultima = plan(days: 4, weeklyKm: 40, deadline: inDays(10)).totalKm
        let carrera = plan(days: 4, weeklyKm: 40, deadline: inDays(3)).totalKm
        #expect(carrera < penultima, "semana de carrera \(carrera) vs. penúltima \(penultima)")
    }

    @Test("El taper baja el volumen, NO la intensidad: la calidad se recorta menos que el rodaje")
    func taperCutsVolumeNotIntensity() {
        // Es el corazón del asunto (Bosquet et al.): recortar también las series pierde economía de
        // carrera y sensación de ritmo. El recorte tiene que caer sobre el volumen fácil.
        let normal = kmByKind(plan(days: 5, weeklyKm: 50, longRunKm: 16))
        let taper = kmByKind(plan(days: 5, weeklyKm: 50, longRunKm: 16, deadline: inDays(3)))

        func recorte(_ kind: PlannedWorkoutKind) -> Double {
            1 - (taper[kind] ?? 0) / (normal[kind] ?? 1)
        }
        for calidad in [PlannedWorkoutKind.intervals, .tempo] {
            #expect(recorte(calidad) < recorte(.easy),
                    "\(calidad.rawValue) se recortó \(recorte(calidad)) y el fácil \(recorte(.easy))")
            #expect(recorte(calidad) < recorte(.longRun))
            #expect((taper[calidad] ?? 0) > 0, "la sesión de calidad no desaparece en taper")
        }
    }

    @Test("El taper no toca la frecuencia: se entrena los mismos días", arguments: 3...6)
    func taperKeepsFrequency(days: Int) {
        let taper = plan(days: days, weeklyKm: 45, deadline: inDays(3))
        #expect(taper.days.count == days)
        // Y siguen siendo las mismas sesiones, no un puñado de rodajes.
        #expect(Set(taper.days.map(\.kind)) == Set(plan(days: days, weeklyKm: 45).days.map(\.kind)))
    }

    @Test("El aviso explica que la semana es corta a propósito")
    func taperIsExplained() {
        let note = plan(days: 4, weeklyKm: 40, deadline: inDays(4)).note
        #expect(note?.contains("afinamiento") == true, "aviso: \(note ?? "nil")")
    }

    @Test("Respeta los días preferidos del atleta")
    func honoursPreferredWeekdays() {
        let preferred = [2, 4, 6]   // lunes, miércoles, viernes
        let week = engine(GeneratePlanUseCase.Input(
            primary: goal(.raceTime, 7200),
            config: PlanConfig(daysPerWeek: 3, preferredWeekdays: preferred),
            currentWeeklyKm: 30
        )).days
        #expect(week.map(\.weekday).sorted() == preferred)
    }

    @Test("A más días la misma carga se reparte en sesiones más cortas")
    func sameLoadSpreadsThinner() {
        let few = plan(days: 3, weeklyKm: 50).days.compactMap(\.targetKm).max() ?? 0
        let many = plan(days: 6, weeklyKm: 50).days
            .filter { $0.kind != .longRun }.compactMap(\.targetKm).max() ?? 0
        let fewNonLong = plan(days: 3, weeklyKm: 50).days
            .filter { $0.kind != .longRun }.compactMap(\.targetKm).max() ?? 0
        #expect(many <= fewNonLong, "con 6 días las sesiones deberían ser <= que con 3")
        #expect(few > 0)
    }

    @Test("Mismo input, mismo plan: el motor es determinista")
    func isDeterministic() {
        let a = plan(days: 5, weeklyKm: 45, longRunKm: 14)
        let b = plan(days: 5, weeklyKm: 45, longRunKm: 14)
        #expect(a.days == b.days)
    }

    // Lo que venía de `GeneratePlanUseCase.selfCheck()`, que corría en un preview de SwiftUI.

    @Test("Cada sesión cae en un día distinto de la semana", arguments: 1...7)
    func noRepeatedWeekdays(days: Int) {
        let week = plan(days: days, weeklyKm: 30, longRunKm: 12).days
        #expect(Set(week.map(\.weekday)).count == days)
    }

    @Test("Volumen alto en pocos días avisa subir días en vez de inflar las sesiones")
    func warnsInsteadOfInflating() {
        // 65 km en 3 días no caben con las sesiones de calidad topadas: tiene que avisar.
        let tight = plan(days: 3, weeklyKm: 65, longRunKm: 26)
        #expect(tight.note != nil)
    }

    @Test("Con más días cabe al menos el mismo volumen — y si no cabe, se avisa")
    func moreDaysFitAtLeastAsMuch() {
        let three = plan(days: 3, weeklyKm: 40, longRunKm: 14)
        let five = plan(days: 5, weeklyKm: 40, longRunKm: 14)

        // Los topes de las sesiones de calidad hacen que en pocos días **no quepa** todo el
        // volumen; eso es deliberado (se avisa subir días en vez de inflar la sesión).
        //
        // Ojo: con 40 km en 3 días sobran ~3 km y el plan **no** avisa, porque el aviso solo
        // salta arriba de `unfitThresholdKm` (5 km). Está documentado en docs/pendientes.md;
        // aquí no se fija ese comportamiento para no cementar un umbral sin calibrar.
        #expect(five.totalKm >= three.totalKm)

        let tempo3 = three.days.first { $0.kind == .tempo }?.targetKm ?? 0
        let tempo5 = five.days.first { $0.kind == .tempo }?.targetKm ?? 0
        #expect(tempo5 <= tempo3 + 0.01, "más días no debe alargar la sesión de calidad")
    }
}
