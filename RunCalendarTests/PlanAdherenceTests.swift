import Foundation
import Testing
@testable import RunCalendar

/// Adherencia de la semana: mide si seguiste el plan sin regañar. Cuenta **totales**, no
/// calendario, y correr de más no sobregira.
@Suite("PlanAdherence · cumplir la semana")
struct PlanAdherenceTests {

    /// Semana de 4 sesiones / 30 km con 2 de calidad, variando lo cumplido.
    private func week(sessions: Int, km: Double, hard: Int = 0, missed: Int = 0) -> PlanAdherence {
        PlanAdherence(plannedSessions: 4, completedSessions: sessions,
                      plannedKm: 30, completedKm: km,
                      plannedHardSessions: 2, completedHardSessions: hard,
                      missedHardDays: missed, completedMinutes: sessions * 40)
    }

    @Test("Semana intacta: 0% y la frase no felicita")
    func untouchedWeek() {
        let none = week(sessions: 0, km: 0)
        #expect(none.fraction == 0)
        #expect(none.summary.contains("Sin sesiones"))
    }

    @Test("Semana al pie de la letra: 100% y felicita")
    func fullWeek() {
        let full = week(sessions: 4, km: 30)
        #expect(full.fraction == 1)
        #expect(full.summary.contains("completa"))
    }

    @Test("Correr de más no pasa de 100%: el plan es un piso, no una cuota")
    func overAchievingCaps() {
        #expect(week(sessions: 6, km: 45).fraction == 1)
    }

    @Test("El volumen pesa más que la frecuencia")
    func volumeOutweighsFrequency() {
        // 2 sesiones largas que cubren el km van mejor que 4 cortas a la mitad.
        #expect(week(sessions: 2, km: 30).fraction > week(sessions: 4, km: 15).fraction)
    }

    @Test("Plan vacío: no divide entre cero ni castiga")
    func emptyPlan() {
        let empty = PlanAdherence(plannedSessions: 0, completedSessions: 0,
                                  plannedKm: 0, completedKm: 0,
                                  plannedHardSessions: 0, completedHardSessions: 0,
                                  missedHardDays: 0, completedMinutes: 0)
        #expect(empty.fraction == 0)
        #expect(empty.kmFraction == 0)
    }
}

/// Campañas: la meta principal convertida en misiones de la semana, con las victorias marcadas
/// desde datos reales. Cuenta victorias **cerradas**, no promedia porcentajes.
@Suite("Campaign · misiones de la semana")
struct CampaignTests {

    private var missions: [CampaignMission] {
        Campaign.planMissions(PlanAdherence(plannedSessions: 4, completedSessions: 2,
                                            plannedKm: 30, completedKm: 30,
                                            plannedHardSessions: 2, completedHardSessions: 0,
                                            missedHardDays: 0, completedMinutes: 80))
    }

    @Test("Las misiones del plan son km, sesiones y calidad")
    func planMissions() {
        #expect(missions.count == 3)
        #expect(missions[0].isDone)       // el km está cubierto
        #expect(!missions[1].isDone)      // faltan sesiones
    }

    @Test("El progreso cuenta victorias cerradas")
    func progressCountsWins() {
        let campaign = Campaign(title: "Primer Medio Maratón", goalHeadline: "21K en 2:00",
                                deadline: nil, missions: missions)
        #expect(campaign.doneCount == 1)
        #expect(campaign.weeksLeft() == nil)
    }

    @Test("Campaña sin misiones: 0 sin dividir entre cero")
    func emptyCampaign() {
        #expect(Campaign(title: "x", goalHeadline: "y", deadline: nil, missions: []).progress == 0)
    }

    @Test("Fecha pasada: 0 semanas, nunca negativas")
    func pastDeadline() {
        let past = Campaign(title: "x", goalHeadline: "y",
                            deadline: Date().addingTimeInterval(-60 * 60 * 24 * 30), missions: [])
        #expect(past.weeksLeft() == 0)
    }
}

/// Aviso de sobreesfuerzo: reponer una sesión perdida **suma** carga que la semana no traía.
/// Es aviso, no candado.
@Suite("PlanAdherence · aviso de carga extra")
struct ExtraLoadWarningTests {

    @Test("Sesión de calidad perdida: pide no encadenar intensidad, no prohíbe reprogramar")
    func missedQualitySession() {
        let warning = PlanAdherence.extraLoadWarning(plannedHard: 2, completedHard: 1, missedHard: 1)
        #expect(warning?.contains("día fácil o de descanso") == true)
        #expect(warning?.lowercased().contains("no la repongas") == false)
    }

    @Test("Calidad ya cubierta: lo que falte, fácil")
    func qualityCovered() {
        let warning = PlanAdherence.extraLoadWarning(plannedHard: 2, completedHard: 2, missedHard: 0)
        #expect(warning?.contains("Ya cubriste") == true)
    }

    @Test("Calidad de más: avisa bajarle")
    func tooMuchQuality() {
        let warning = PlanAdherence.extraLoadWarning(plannedHard: 2, completedHard: 3, missedHard: 0)
        #expect(warning?.contains("exceso de intensidad") == true)
    }

    @Test("A media semana y al día no se advierte nada")
    func nothingToWarnAbout() {
        #expect(PlanAdherence.extraLoadWarning(plannedHard: 2, completedHard: 1, missedHard: 0) == nil)
        #expect(PlanAdherence.extraLoadWarning(plannedHard: 0, completedHard: 0, missedHard: 0) == nil)
    }
}

/// El día del plan: lo pedido vs. lo hecho. La tolerancia es híbrida —`max(500 m, 5%)`— porque un
/// porcentaje fijo trata igual 400 m de una sesión de 4 km que 2 km de una de 20.
@Suite("PlanDayOutcome · el día por día")
struct PlanDayOutcomeTests {

    private func status(_ planned: Double?, _ done: Double,
                        passed: Bool = true) -> PlanDayOutcome.Status {
        PlanDayOutcome.status(plannedKm: planned, doneKm: done, hasPassed: passed)
    }

    @Test("La posición del día respeta el primer día de la semana del usuario")
    func weekdayPosition() {
        var monday = Calendar(identifier: .gregorian)
        monday.firstWeekday = 2
        #expect(PlannedDay.position(of: 2, calendar: monday) == 0)
        #expect(PlannedDay.position(of: 1, calendar: monday) == 6)   // domingo, el último

        var sunday = Calendar(identifier: .gregorian)
        sunday.firstWeekday = 1
        #expect(PlannedDay.position(of: 1, calendar: sunday) == 0)
    }

    @Test("Tolerancia híbrida: manda el piso de 500 m en sesiones cortas y el 5% en largas")
    func hybridTolerance() {
        #expect(PlanDayOutcome.minimumKm(for: 4) == 3.5)
        #expect(PlanDayOutcome.minimumKm(for: 20) == 19)
        #expect(status(4, 3.6) == .done)
        #expect(status(4, 3.4) == .partial)
        #expect(status(20, 19.2) == .done)
        #expect(status(20, 18) == .partial)      // 2 km de menos sí importan
    }

    @Test("Estados del día")
    func dayStatuses() {
        #expect(status(8, 8.2) == .done)         // de más sigue siendo cumplido
        #expect(status(8, 5.2) == .partial)
        #expect(status(8, 0) == .missed)
        #expect(status(8, 0, passed: false) == .upcoming)   // el día que no llega no se juzga
        #expect(status(nil, 6) == .extra)        // corriste en día de descanso
        #expect(status(nil, 0) == .rest)
    }

    @Test("La frase dice el faltante, que es lo que el atleta quiere saber")
    func summaryStatesTheGap() {
        let partial = PlanDayOutcome(weekday: 2, plannedKind: .tempo, plannedKm: 8,
                                     doneKm: 5.2, doneMinutes: 30, status: .partial)
        #expect(partial.summary.contains("Tempo de 8 km"))
        #expect(partial.summary.contains("5.2 km en 30 min"))
        #expect(partial.summary.contains("faltaron 2.8 km"))

        let skipped = PlanDayOutcome(weekday: 3, plannedKind: .intervals, plannedKm: 6,
                                     doneKm: 0, doneMinutes: 0, status: .missed)
        #expect(skipped.summary.contains("Series de 6 km"))
        #expect(skipped.summary.contains("sin sesión"))
    }
}

/// Semanas que no se miden: sin esto la adherencia marca 0% al atleta que no entrenó por gripe o
/// lesión — o sea, le dice que falló justo cuando acertó.
@Suite("WeekStatus · semanas en pausa")
struct WeekStatusTests {

    @Test("Lesión y enfermedad paran el entrenamiento; la descarga no")
    func pausesTraining() {
        #expect(WeekStatus.injured.pausesTraining)
        #expect(WeekStatus.sick.pausesTraining)
        #expect(!WeekStatus.deload.pausesTraining)   // se entrena menos, no se deja de entrenar
    }

    @Test("Los tres explican por qué, sin dejar un porcentaje en blanco",
          arguments: WeekStatus.allCases)
    func explainsItself(status: WeekStatus) {
        #expect(status.message.contains("pausa"))
        #expect(!status.hint.isEmpty)
    }

    @Test("El rawValue es estable: se persiste en UserDefaults")
    func stableRawValue() {
        #expect(WeekStatus(rawValue: "Lesionado") == .injured)
    }
}
