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
