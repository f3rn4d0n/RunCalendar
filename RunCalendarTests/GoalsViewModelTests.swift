import Foundation
import Testing
@testable import RunCalendar

/// `GoalsViewModel` — la primera prueba que atraviesa el **cableado**, no un caso de uso suelto.
///
/// Lo que se cubre aquí no vive en ningún motor: qué sesiones alimentan el plan, cuándo la semana
/// se pausa, qué se persiste al crear una meta. Son las costuras entre piezas, que es justo donde
/// las pruebas por caso de uso no llegan.
///
/// `.serialized` porque `planConfig` y `weekStatus` viven en `UserDefaults`, que es global.
@Suite("GoalsViewModel · el cableado del plan", .serialized)
@MainActor
struct GoalsViewModelTests {

    private let cal = Calendar.current

    private func session(_ type: TrainingType, km: Double, daysAgo: Int,
                         rpe: Int? = nil, completed: Bool = true) -> TrainingSession {
        TrainingSession(
            date: cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
            type: type,
            title: "Sesión de prueba",
            distanceKm: km,
            completed: completed,
            rpe: rpe
        )
    }

    private func volumeGoal(_ km: Double = 45) -> Goal {
        Goal(type: .weeklyVolume, targetValue: km)
    }

    // MARK: - Qué volumen alimenta el plan

    @Test("El plan se construye sobre lo que corres, no sobre lo que caminas")
    func planUsesRunningOnly() async {
        // Contar caminatas inflaba el volumen y disparaba avisos falsos de "no cabe en 3 días".
        let app = TestApp(goals: [volumeGoal()], sessions: [
            session(.running, km: 10, daysAgo: 1),
            session(.running, km: 10, daysAgo: 3),
            session(.walking, km: 15, daysAgo: 2),
            session(.hiking, km: 12, daysAgo: 4)
        ])
        await app.start()

        let plan = app.goals.currentPlan
        #expect(plan != nil)
        // 20 km de correr: el plan sube ~8% sobre eso, no sobre los 47 que suman las cuatro.
        #expect((plan?.totalKm ?? 0) < 30, "totalKm = \(plan?.totalKm ?? 0)")
    }

    @Test("Las sesiones sin completar no cuentan como volumen")
    func plannedButNotDoneDoesNotCount() async {
        let app = TestApp(goals: [volumeGoal()], sessions: [
            session(.running, km: 10, daysAgo: 1),
            session(.running, km: 40, daysAgo: 2, completed: false)
        ])
        await app.start()
        #expect((app.goals.currentPlan?.totalKm ?? 0) < 20)
    }

    @Test("Sin ninguna meta no hay plan que mostrar")
    func noGoalNoPlan() async {
        let app = TestApp(sessions: [session(.running, km: 10, daysAgo: 1)])
        await app.start()
        #expect(app.goals.currentPlan == nil)
        #expect(app.goals.todayMission == nil)
    }

    @Test("Una meta de volumen ancla el plan aunque no haya meta de tiempo")
    func parameterGoalAnchorsThePlan() async {
        // `inferPrimary` solo mira metas driver (tiempo/VO₂max); sin ellas el plan se quedaba en
        // nil y la app no proponía nada a quien solo quiere subir kilómetros.
        let app = TestApp(goals: [volumeGoal()], sessions: [session(.running, km: 20, daysAgo: 1)])
        await app.start()
        #expect(app.goals.planAnchorGoal?.type == .weeklyVolume)
        #expect(app.goals.currentPlan != nil)
    }

    // MARK: - La semana en pausa

    @Test("Lesión y enfermedad pausan la adherencia y dejan de empujar la sesión de hoy",
          arguments: [WeekStatus.injured, .sick])
    func pausedWeekStopsPushing(status: WeekStatus) async {
        let app = TestApp(goals: [volumeGoal()], sessions: [session(.running, km: 20, daysAgo: 1)])
        await app.start()
        #expect(app.goals.weekAdherence != nil, "sin pausa sí hay adherencia")

        app.goals.weekStatus = status
        #expect(app.goals.weekAdherence == nil, "marcar 0% a quien hizo lo correcto es un castigo")
        #expect(app.goals.todayMission == nil, "no se le empuja una sesión a quien no puede entrenar")
    }

    @Test("Una descarga pausa la adherencia pero sigue proponiendo entrenar")
    func deloadKeepsTraining() async {
        // La diferencia con lesión: en descarga se entrena menos, no se deja de entrenar.
        let app = TestApp(goals: [volumeGoal()], sessions: [session(.running, km: 20, daysAgo: 1)])
        await app.start()
        app.goals.weekStatus = .deload

        #expect(app.goals.weekAdherence == nil)
        // Si el plan pide entrenar hoy, la misión sigue ahí; si hoy es descanso, es nil por otro
        // motivo. Se comprueba contra el plan para no depender del día en que corran las pruebas.
        let plannedToday = app.goals.currentPlan?.today()
        #expect(app.goals.todayMission == plannedToday)
    }

    @Test("Al cambiar de semana el estado caduca solo")
    func weekStatusExpires() async {
        let app = TestApp(goals: [volumeGoal()], sessions: [session(.running, km: 20, daysAgo: 1)])
        await app.start()
        app.goals.weekStatus = .injured

        // Se simula el cambio de semana moviendo la fecha guardada al pasado, que es lo que hace
        // el paso del tiempo. Sin caducidad, una lesión de hace un mes seguiría pausando la app.
        UserDefaults.standard.set(cal.date(byAdding: .day, value: -14, to: Date()),
                                  forKey: "week.status.weekStart")
        #expect(app.goals.weekStatus == nil)
    }

    // MARK: - Adherencia

    @Test("Mover las sesiones de día no castiga: cuenta el total, no el calendario")
    func adherenceCountsTotalsNotDays() async {
        let app = TestApp(goals: [volumeGoal()], sessions: [])
        await app.start()
        guard let plan = app.goals.currentPlan else {
            Issue.record("hace falta un plan para medir adherencia")
            return
        }

        // Se corre exactamente lo que el plan pide, pero **todo hoy**. Es el caso extremo de mover
        // sesiones: un conteo por calendario vería una de tres. Hoy y no "un día que el plan no
        // pedía" para que la prueba no dependa del día en que corra (los días futuros no cuentan).
        let done = plan.days.map { day in
            TrainingSession(date: Date(), type: .running, title: "Todo el mismo día",
                            distanceKm: day.targetKm ?? 0, completed: true)
        }

        let moved = TestApp(goals: [volumeGoal()], sessions: done)
        await moved.start()
        let adherence = moved.goals.weekAdherence
        #expect(adherence?.completedSessions == plan.days.count)
        #expect((adherence?.completedKm ?? 0) == plan.totalKm)
    }

    @Test("La semana día por día no juzga los días que todavía no llegan")
    func futureDaysAreNotJudged() async {
        let app = TestApp(goals: [volumeGoal()], sessions: [session(.running, km: 20, daysAgo: 1)])
        await app.start()

        // Las dos direcciones, porque una u otra queda vacía según el día en que corran las
        // pruebas: el domingo no hay días pasados y el sábado no hay futuros.
        let todayPosition = PlannedDay.position(of: cal.component(.weekday, from: Date()))
        for outcome in app.goals.weekOutcomes {
            let position = PlannedDay.position(of: outcome.weekday)
            if position >= todayPosition {
                // Hoy incluido: el día no ha terminado, todavía puedes salir a correr.
                #expect(outcome.status == .upcoming, "\(outcome.weekday) ya se está juzgando")
            } else {
                #expect(outcome.status != .upcoming, "\(outcome.weekday) ya pasó y sigue pendiente")
            }
        }
        #expect(app.goals.weekOutcomes.count == 7, "la semana completa, con descansos")
    }

    // MARK: - Guardar

    @Test("Al crear una meta se captura el punto de partida, para que la barra tenga base")
    func newGoalCapturesStartValue() async {
        let app = TestApp(sessions: [
            session(.running, km: 12, daysAgo: 1),
            session(.running, km: 8, daysAgo: 3)
        ])
        await app.start()

        _ = await app.goals.save(Goal(type: .weeklyVolume, targetValue: 50), isNew: true)

        #expect(app.goalRepo.added.count == 1)
        #expect(app.goalRepo.added.first?.startValue == 20, "20 km corridos esta semana")
    }

    @Test("Editar una meta no reescribe su punto de partida")
    func editingKeepsStartValue() async {
        let existing = Goal(type: .weeklyVolume, targetValue: 40, startValue: 15)
        let app = TestApp(goals: [existing], sessions: [session(.running, km: 30, daysAgo: 1)])
        await app.start()

        var edited = existing
        edited.targetValue = 60
        _ = await app.goals.save(edited, isNew: false)

        #expect(app.goalRepo.updated.first?.startValue == 15, "el arranque es historia, no se mueve")
        #expect(app.goalRepo.added.isEmpty)
    }

    @Test("Si guardar falla, el error llega a la vista en vez de perderse")
    func saveFailureSurfaces() async {
        let app = TestApp()
        await app.start()
        app.goalRepo.failure = FakeFailure()

        let ok = await app.goals.save(Goal(type: .weeklyVolume, targetValue: 50), isNew: true)
        #expect(ok == false)
        #expect(app.goals.errorMessage != nil)
    }

    @Test("Aplicar una sugerencia actualiza la meta de volumen en vez de duplicarla")
    func applySuggestionUpdatesInsteadOfDuplicating() async {
        let app = TestApp(goals: [volumeGoal(30)], sessions: (1...9).map {
            session(.running, km: 8, daysAgo: $0 * 3)
        })
        await app.start()
        guard let suggestion = app.goals.planSuggestion() else {
            Issue.record("con 9 corridas en 27 días debería haber sugerencia")
            return
        }

        await app.goals.applyPlanSuggestion(suggestion)

        #expect(app.goalRepo.added.isEmpty, "ya había meta de volumen: se edita, no se crea otra")
        #expect(app.goalRepo.updated.count == 1)
        #expect(app.goals.planConfig.daysPerWeek == suggestion.config.daysPerWeek)
    }

    // MARK: - Seguimiento corporal

    @Test("Sin permiso de escritura en Salud no se pide registrar el peso")
    func noWeightPromptWithoutHealthKit() async {
        let app = TestApp(goals: [Goal(type: .weight, targetValue: 70)])
        await app.start()
        // `available = false` por defecto: es un Mac, o alguien que negó el permiso.
        #expect(app.goals.canLogMeasures == false)
        #expect(app.goals.needsWeightLog == false, "pedir lo que no se puede guardar es un callejón")
    }

    @Test("Registrar el peso lo guarda en Salud y refresca el historial")
    func loggingWeightRefreshes() async {
        let app = TestApp(goals: [Goal(type: .weight, targetValue: 70)])
        app.healthRepo.available = true
        await app.start()

        let ok = await app.goals.logMeasure(.weight, value: 74.5)

        #expect(ok)
        #expect(app.healthRepo.savedMeasures.first?.value == 74.5)
        #expect(app.goals.latestWeight?.value == 74.5, "la vista lo ve sin recargar a mano")
    }

    @Test("Si Salud rechaza la escritura, el mensaje explica cómo activarla")
    func healthWriteDeniedExplainsHow() async {
        let app = TestApp(goals: [Goal(type: .weight, targetValue: 70)])
        app.healthRepo.available = true
        app.healthRepo.saveFailure = HealthWriteError.measureNotAuthorized(.weight)
        await app.start()

        let ok = await app.goals.logMeasure(.weight, value: 74.5)

        #expect(ok == false)
        // iOS no vuelve a mostrar la hoja de permisos: sin la ruta exacta el usuario queda atorado.
        #expect(app.goals.errorMessage?.contains("Salud") == true)
    }

    @Test("El review dominical parte las medidas a Salud y lo subjetivo a Firestore")
    func reviewSplitsItsData() async {
        let app = TestApp()
        app.healthRepo.available = true
        await app.start()

        let ok = await app.goals.saveReview(weight: 74, waist: 82, energy: 4, hunger: 2, notes: "ok")

        #expect(ok)
        #expect(app.healthRepo.savedMeasures.map(\.measure) == [.weight, .waist])
        #expect(app.bodyLogRepo.saved.first?.energy == 4)
        #expect(app.goals.hasReviewThisWeek)
    }

    @Test("Un review sin peso capturado no escribe nada en Salud")
    func reviewWithoutMeasuresWritesNothing() async {
        let app = TestApp()
        app.healthRepo.available = true
        await app.start()

        _ = await app.goals.saveReview(weight: nil, waist: nil, energy: 3, hunger: 3, notes: "")

        #expect(app.healthRepo.savedMeasures.isEmpty, "nil = no lo capturaste, no = bórralo")
        #expect(app.bodyLogRepo.saved.count == 1)
    }
}
