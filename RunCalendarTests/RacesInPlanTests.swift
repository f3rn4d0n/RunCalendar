import Foundation
import Testing
@testable import RunCalendar

/// Carreras inscritas dentro del plan de la semana. Una carrera no es una sugerencia del motor:
/// es un compromiso del calendario del atleta, así que el plan se acomoda **alrededor** de ella.
@Suite("GeneratePlanUseCase · carreras inscritas")
struct RacesInPlanTests {

    private let engine = GeneratePlanUseCase()
    private let cal = Calendar.current

    /// Lunes de la semana en curso, para colocar carreras en días concretos.
    private var weekStart: Date {
        cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    }

    private func race(_ discipline: RaceDiscipline, daysFromWeekStart: Int,
                      registered: Bool = true, km: Double? = nil,
                      name: String = "Carrera de prueba") -> Race {
        Race(name: name,
             date: cal.date(byAdding: .day, value: daysFromWeekStart, to: weekStart) ?? weekStart,
             discipline: discipline,
             distanceKm: km,
             location: RaceLocation(name: "Ciudad"),
             isRegistered: registered)
    }

    private func plan(days: Int = 4, weeklyKm: Double = 40, races: [Race]) -> TrainingPlan {
        engine(GeneratePlanUseCase.Input(
            primary: Goal(type: .raceTime, targetValue: 7200),
            config: PlanConfig(daysPerWeek: days),
            currentWeeklyKm: weeklyKm,
            currentLongRunKm: 12,
            races: races,
            weekStart: weekStart
        ))
    }

    // MARK: - Qué entra al plan

    @Test("Una carrera inscrita de esta semana aparece en el plan, en su día")
    func registeredRaceAppears() {
        let week = plan(races: [race(.tenK, daysFromWeekStart: 3)]).days
        let raceDay = week.first { $0.kind == .race }
        #expect(raceDay != nil)
        #expect(raceDay?.targetKm == 10)
        #expect(raceDay?.isFixed == true)
    }

    @Test("Una carrera que solo estás considerando NO reestructura la semana")
    func unregisteredRaceIsIgnored() {
        let week = plan(races: [race(.halfMarathon, daysFromWeekStart: 3, registered: false)]).days
        #expect(!week.contains { $0.kind == .race })
    }

    @Test("Una carrera de otra semana no entra")
    func raceOutsideTheWeekIsIgnored() {
        let week = plan(races: [race(.tenK, daysFromWeekStart: 20)]).days
        #expect(!week.contains { $0.kind == .race })
    }

    @Test("Una carrera ya completada no entra")
    func completedRaceIsIgnored() {
        var past = race(.tenK, daysFromWeekStart: 2)
        past.status = .completed
        #expect(!plan(races: [past]).days.contains { $0.kind == .race })
    }

    // MARK: - El día es fijo

    @Test("El día de la carrera no lleva además otra sesión")
    func noDoubleSessionOnRaceDay() {
        // Es el bug que motivó todo: "Tirada larga 18 km" el domingo que corres un 21K.
        let raceWeekday = 4
        let week = plan(races: [race(.halfMarathon, daysFromWeekStart: raceWeekday)]).days
        let weekday = cal.component(.weekday,
                                    from: cal.date(byAdding: .day, value: raceWeekday,
                                                   to: weekStart) ?? weekStart)
        #expect(week.filter { $0.weekday == weekday }.count == 1)
    }

    @Test("La carrera queda marcada como día fijo y las demás sesiones no")
    func onlyRacesAreFixed() {
        let week = plan(races: [race(.tenK, daysFromWeekStart: 3)]).days
        for day in week {
            #expect(day.isFixed == (day.kind == .race))
        }
    }

    // MARK: - El volumen cuadra

    @Test("Los km de la carrera cuentan dentro del volumen, no encima")
    func raceKmComeOutOfTheBudget() {
        // Sin carrera la semana pide ~X km. Con un 21K inscrito debe pedir aproximadamente lo
        // mismo *en total* — no X + 21, que sería un salto del 50% que el propio techo prohíbe.
        let sinCarrera = plan(races: []).totalKm
        let con = plan(races: [race(.halfMarathon, daysFromWeekStart: 5)])

        let kmDeCarrera = con.days.first { $0.kind == .race }?.targetKm ?? 0
        let kmDeEntrenamiento = con.totalKm - kmDeCarrera

        #expect(kmDeCarrera > 0, "la carrera tiene que estar en el plan")
        // Lo que de verdad importa: el plan pide **menos entrenamiento** porque la carrera ya
        // aporta volumen. Sin esto la prueba pasaría aunque la carrera se ignorara por completo.
        #expect(kmDeEntrenamiento < sinCarrera,
                "entrenamiento \(kmDeEntrenamiento) vs \(sinCarrera) sin carrera")
        #expect(con.totalKm <= sinCarrera + 1, "\(con.totalKm) vs \(sinCarrera) sin carrera")
    }

    @Test("La carrera sustituye a la sesión de calidad, no se suma a ella")
    func raceReplacesQualitySession() {
        // Un 10K a tope ya es la sesión dura: la semana no debe pedir además series.
        let week = plan(races: [race(.tenK, daysFromWeekStart: 5)]).days
        let hard = week.filter { $0.kind.isHard }
        let sinCarrera = plan(races: []).days.filter { $0.kind.isHard }
        #expect(hard.count <= sinCarrera.count)
        #expect(hard.contains { $0.kind == .race })
    }

    @Test("Una carrera larga ocupa el lugar de la tirada larga")
    func longRaceReplacesTheLongRun() {
        let week = plan(races: [race(.marathon, daysFromWeekStart: 6)]).days
        #expect(!week.contains { $0.kind == .longRun }, "no se corre una larga además del maratón")
    }

    // MARK: - Sin distancia conocida

    @Test("Trail sin km fija el día pero no inventa una distancia")
    func trailWithoutDistanceDoesNotGuess() {
        let week = plan(races: [race(.trail, daysFromWeekStart: 5)]).days
        let raceDay = week.first { $0.kind == .race }
        #expect(raceDay != nil)
        #expect(raceDay?.targetKm == nil, "no debe inventarse un número")
        #expect(raceDay?.detail.contains("Captura") == true, "debe pedir la distancia")
    }

    @Test("Trail con km capturados sí cuenta para el volumen")
    func trailWithDistanceCounts() {
        let week = plan(races: [race(.trail, daysFromWeekStart: 5, km: 18)]).days
        #expect(week.first { $0.kind == .race }?.targetKm == 18)
    }

    // MARK: - La víspera

    /// Día de la semana que cae `offset` días después del inicio de la semana del usuario.
    private func weekday(offset: Int) -> Int {
        cal.component(.weekday, from: cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart)
    }

    @Test("La víspera de la carrera no lleva una sesión exigente", arguments: [3, 4, 5, 6, 7])
    func noHardSessionOnRaceEve(days: Int) {
        // Carrera el último día de la semana: la víspera es el penúltimo. Es el caso del domingo
        // con el plan llegando hasta el sábado. Se barren todos los días/semana porque con pocos
        // días la víspera queda en descanso (que también cumple) y con muchos sí se ocupa.
        let week = plan(days: days, races: [race(.tenK, daysFromWeekStart: 6)]).days
        let eve = week.first { $0.weekday == weekday(offset: 5) }
        #expect(eve?.kind.isHard != true, "cayó \(eve?.kind.rawValue ?? "—") en la víspera")
        #expect(eve?.kind != .longRun, "la tirada larga tampoco va en víspera")
    }

    @Test("Si la semana no llena la víspera, queda en descanso — que también cumple la regla")
    func eveMaySimplyBeRest() {
        let week = plan(days: 5, races: [race(.tenK, daysFromWeekStart: 6)]).days
        let eve = week.first { $0.weekday == weekday(offset: 5) }
        // Con 5 días la víspera ni se usa. Lo que importa es que no sea exigente, lo esté o no.
        #expect(eve == nil || eve?.kind == .easy)
    }

    @Test("La víspera queda como el día más corto de la semana")
    func eveIsTheShortestDay() {
        // 7 días: todos los días no-carrera llevan sesión, así que la víspera seguro está ocupada.
        let week = plan(days: 7, races: [race(.tenK, daysFromWeekStart: 6)]).days
        guard let eve = week.first(where: { $0.weekday == weekday(offset: 5) }) else {
            Issue.record("con 7 días la víspera debería llevar sesión")
            return
        }
        // Relativo, no un número fijo: no cementa el tope de la víspera, solo que es un rodaje corto.
        let otras = week.filter { $0.kind != .race && $0.weekday != eve.weekday }
            .compactMap(\.targetKm)
        for km in otras {
            #expect((eve.targetKm ?? 0) <= km, "la víspera (\(eve.targetKm ?? 0)) no es la más corta")
        }
    }

    @Test("El texto de la víspera ofrece las dos opciones en vez de prescribir una")
    func eveOffersBothOptions() {
        // No hay ensayos que comparen descanso contra rodaje corto: la app no debe elegir por ti.
        let week = plan(days: 7, races: [race(.tenK, daysFromWeekStart: 6)]).days
        let eve = week.first { $0.weekday == weekday(offset: 5) }
        #expect(eve?.detail.lowercased().contains("descanso") == true)
        #expect(eve?.detail.contains("suaves") == true)
    }

    @Test("Una carrera el primer día de la semana no rompe nada (su víspera es de otra semana)")
    func raceOnFirstDayHasNoEveToProtect() {
        let week = plan(days: 4, races: [race(.tenK, daysFromWeekStart: 0)]).days
        #expect(week.contains { $0.kind == .race })
        #expect(week.count >= 1)
    }

    @Test("Si no se puede dejar la víspera suave, el aviso lo dice y no pide mover la carrera")
    func warnsWhenTheEveCannotBeProtected() {
        // 3 días = series + tempo + larga: al sustituir una por la carrera no queda ninguna sesión
        // fácil con la que intercambiar. Se dan exactamente los días que se van a usar, uno de
        // ellos la víspera, para que la exigente no tenga a dónde moverse.
        let plan = engine(GeneratePlanUseCase.Input(
            primary: Goal(type: .raceTime, targetValue: 7200),
            config: PlanConfig(daysPerWeek: 3,
                               preferredWeekdays: [weekday(offset: 1), weekday(offset: 5)]),
            currentWeeklyKm: 40,
            currentLongRunKm: 12,
            races: [race(.tenK, daysFromWeekStart: 6)],
            weekStart: weekStart
        ))
        #expect(plan.note?.contains("carrera") == true, "aviso: \(plan.note ?? "nil")")
        // El aviso no puede pedir mover un día fijo.
        #expect(plan.note?.contains("mueve la carrera") != true)
    }

    // MARK: - Guía

    @Test("La guía de una carrera dice que el día es fijo y no le inventa ritmo")
    func raceGuideExplainsItIsFixed() {
        let week = plan(races: [race(.tenK, daysFromWeekStart: 3, name: "Carrera de la Ciudad")]).days
        let raceDay = week.first { $0.kind == .race }!
        let guide = DescribeWorkoutUseCase()(raceDay)
        #expect(guide.headline == "Carrera de la Ciudad")
        #expect(guide.rationale.contains("fijo"))
        #expect(guide.structure.steadyKm == 10)
    }
}
