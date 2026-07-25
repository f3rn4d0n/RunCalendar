// Check de PlanAdherence y Campaign.progress. Compila contra los archivos reales (no duplica la
// lógica) y no necesita simulador ni target de tests. Desde la raíz del repo:
//
//   swiftc RunCalendar/Domain/Entities/TrainingPlan.swift RunCalendar/Domain/Entities/Goal.swift \
//     RunCalendar/Domain/Entities/Campaign.swift RunCalendar/Domain/Entities/Race.swift \
//     Scripts/check-adherence.swift -module-name check -o /tmp/check-adherence && /tmp/check-adherence
//
// Sin -O a propósito: en release los `assert` se compilan fuera y el check no verificaría nada.

import Foundation

@main struct CheckAdherence {
    /// Semana de 4 sesiones / 30 km con 2 de calidad, variando lo cumplido.
    static func plan(sessions: Int, km: Double, hard: Int = 0, missed: Int = 0) -> PlanAdherence {
        PlanAdherence(plannedSessions: 4, completedSessions: sessions,
                      plannedKm: 30, completedKm: km,
                      plannedHardSessions: 2, completedHardSessions: hard,
                      missedHardDays: missed, completedMinutes: sessions * 40)
    }

    static func main() {
        // 1) Semana intacta: nada hecho => 0, y la frase no felicita.
        let none = plan(sessions: 0, km: 0)
        assert(none.fraction == 0, "sin nada hecho: \(none.fraction)")
        assert(none.summary.contains("Sin sesiones"), "frase: \(none.summary)")

        // 2) Semana cumplida al pie de la letra => 1 y felicita.
        let full = plan(sessions: 4, km: 30)
        assert(full.fraction == 1, "semana completa: \(full.fraction)")
        assert(full.summary.contains("completa"), "frase: \(full.summary)")

        // 3) Correr de más NO pasa de 100%: el plan es un piso, no una cuota que se sobregira.
        let over = plan(sessions: 6, km: 45)
        assert(over.fraction == 1, "de más sigue siendo 1: \(over.fraction)")

        // 4) El volumen manda sobre la frecuencia: 2 sesiones largas que cubren el km de la semana
        //    van mejor que 4 sesiones cortas que se quedan a la mitad.
        let fewLong = plan(sessions: 2, km: 30)
        let manyShort = plan(sessions: 4, km: 15)
        assert(fewLong.fraction > manyShort.fraction,
               "volumen debe pesar más: \(fewLong.fraction) vs \(manyShort.fraction)")

        // 5) Plan vacío (semana de descanso total): no divide entre cero ni castiga.
        let empty = PlanAdherence(plannedSessions: 0, completedSessions: 0, plannedKm: 0, completedKm: 0,
                                  plannedHardSessions: 0, completedHardSessions: 0,
                                  missedHardDays: 0, completedMinutes: 0)
        assert(empty.fraction == 0 && empty.kmFraction == 0, "plan vacío: \(empty.fraction)")

        // 6) Campaign.progress cuenta victorias cerradas, no promedia porcentajes.
        let missions = Campaign.planMissions(fewLong)
        assert(missions.count == 3, "km + sesiones + calidad: \(missions.count)")
        assert(missions[0].isDone, "el km está cubierto => misión cerrada")
        assert(!missions[1].isDone, "faltan sesiones => misión abierta")

        let campaign = Campaign(title: "Primer Medio Maratón", goalHeadline: "21K en 2:00",
                                deadline: nil, missions: missions)
        assert(campaign.doneCount == 1, "1 de 3 misiones cerradas: \(campaign.doneCount)")
        assert(campaign.weeksLeft() == nil, "sin fecha no hay semanas")

        // 7) Campaña sin misiones: progreso 0, sin dividir entre cero.
        let bare = Campaign(title: "x", goalHeadline: "y", deadline: nil, missions: [])
        assert(bare.progress == 0, "campaña vacía: \(bare.progress)")

        // 8) Fecha pasada => 0 semanas, nunca negativas.
        let past = Campaign(title: "x", goalHeadline: "y",
                            deadline: Date().addingTimeInterval(-60 * 60 * 24 * 30), missions: [])
        assert(past.weeksLeft() == 0, "fecha pasada: \(past.weeksLeft() as Any)")

        // 9) Sobreesfuerzo: reponer la sesión perdida suma carga que la semana no traía.
        //    Es el caso que motivó el aviso: intentaste series el martes, no salió, y el miércoles
        //    quieres repetir.
        let missed = PlanAdherence.extraLoadWarning(plannedHard: 2, completedHard: 1, missedHard: 1)
        // No prohíbe reprogramar: pide no encadenar intensidad para compensar.
        assert(missed?.contains("día fácil o de descanso") == true, "aviso: \(missed ?? "nil")")
        assert(missed?.lowercased().contains("no la repongas") == false, "no debe ser una prohibición")

        // 10) Ya cubriste la calidad de la semana => lo que falte, fácil.
        let covered = PlanAdherence.extraLoadWarning(plannedHard: 2, completedHard: 2, missedHard: 0)
        assert(covered?.contains("Ya cubriste") == true, "cubierta: \(covered ?? "nil")")

        // 11) Calidad de más => avisa bajarle, y pesa más que el aviso de "ya cubriste".
        let excess = PlanAdherence.extraLoadWarning(plannedHard: 2, completedHard: 3, missedHard: 0)
        assert(excess?.contains("exceso de intensidad") == true, "exceso: \(excess ?? "nil")")

        // 12) Semana en curso y al día: nada que advertir (no regañar sin motivo).
        assert(PlanAdherence.extraLoadWarning(plannedHard: 2, completedHard: 1, missedHard: 0) == nil,
               "a media semana sin días perdidos no se advierte")
        // Plan sin sesiones de calidad: tampoco.
        assert(PlanAdherence.extraLoadWarning(plannedHard: 0, completedHard: 0, missedHard: 0) == nil,
               "plan sin calidad")

        // 13) La posición del día respeta el primer día de la semana del usuario: con semana que
        //     empieza en lunes, el domingo es el último día aunque su número sea el más bajo.
        var monday = Calendar(identifier: .gregorian)
        monday.firstWeekday = 2
        assert(PlannedDay.position(of: 2, calendar: monday) == 0, "lunes es el primero")
        assert(PlannedDay.position(of: 1, calendar: monday) == 6, "domingo es el último")
        var sunday = Calendar(identifier: .gregorian)
        sunday.firstWeekday = 1
        assert(PlannedDay.position(of: 1, calendar: sunday) == 0, "con semana en domingo, es el primero")

        // 14) Estado de cada día: lo pedido vs. lo hecho.
        typealias Status = PlanDayOutcome.Status
        func status(_ planned: Double?, _ done: Double, passed: Bool = true) -> Status {
            PlanDayOutcome.status(plannedKm: planned, doneKm: done, hasPassed: passed)
        }
        assert(status(8, 8.2) == .done, "de más sigue siendo cumplido")
        assert(status(8, 5.2) == .partial, "5.2 de 8 es parcial")

        // Tolerancia híbrida max(500 m, 5%): un porcentaje fijo trata igual 400 m de una sesión
        // de 4 km (irrelevantes) que 2 km de una de 20 (media hora de trote).
        assert(PlanDayOutcome.minimumKm(for: 4) == 3.5, "4 km: manda el piso de 500 m")
        assert(PlanDayOutcome.minimumKm(for: 20) == 19, "20 km: manda el 5%")
        assert(status(4, 3.6) == .done, "3.6 de 4 entra por el piso")
        assert(status(4, 3.4) == .partial, "3.4 de 4 ya no")
        assert(status(20, 19.2) == .done, "19.2 de 20 entra por el 5%")
        assert(status(20, 18) == .partial, "18 de 20 son 2 km de menos: parcial")
        assert(status(8, 0) == .missed, "día pasado sin correr")
        assert(status(8, 0, passed: false) == .upcoming, "el día que no llega no se juzga")
        assert(status(nil, 6) == .extra, "corriste en día de descanso")
        assert(status(nil, 0) == .rest, "descanso respetado")

        // 15) La frase dice el faltante, que es lo que el atleta quiere saber.
        let partial = PlanDayOutcome(weekday: 2, plannedKind: .tempo, plannedKm: 8,
                                     doneKm: 5.2, doneMinutes: 30, status: .partial)
        assert(partial.summary.contains("Tempo de 8 km"), "pedido: \(partial.summary)")
        assert(partial.summary.contains("5.2 km en 30 min"), "hecho: \(partial.summary)")
        assert(partial.summary.contains("faltaron 2.8 km"), "faltante: \(partial.summary)")

        let skipped = PlanDayOutcome(weekday: 3, plannedKind: .intervals, plannedKm: 6,
                                     doneKm: 0, doneMinutes: 0, status: .missed)
        assert(skipped.summary.contains("Series de 6 km") && skipped.summary.contains("sin sesión"),
               "no hecha: \(skipped.summary)")

        print("ok: los 40 checks de PlanAdherence, Campaign y PlanDayOutcome pasan")
    }
}
