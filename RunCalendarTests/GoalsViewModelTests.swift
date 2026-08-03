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

        let todayPosition = PlannedDay.position(of: cal.component(.weekday, from: Date()))
        let plansFrom = app.goals.currentPlan?.plansFrom ?? 0
        for outcome in app.goals.weekOutcomes {
            // Hoy cuenta como "todavía no llega": el día no ha terminado y aún puedes salir.
            let hasPassed = PlannedDay.position(of: outcome.weekday) < todayPosition

            let beforePlan = PlannedDay.position(of: outcome.weekday) < plansFrom
            guard let plannedKm = outcome.plannedKm, plannedKm > 0 else {
                // Un día que no pedía nada no se juzga en ninguna dirección, pase o no pase. Si
                // además es anterior al plan, lo que corriste cuenta como hecho y no como "extra".
                #expect(outcome.status == (outcome.doneKm > 0 ? (beforePlan ? .done : .extra) : .rest))
                continue
            }
            if outcome.doneKm == 0 {
                #expect(outcome.status == (hasPassed ? .missed : .upcoming),
                        "día \(outcome.weekday): \(outcome.status)")
            }
        }
        #expect(app.goals.weekOutcomes.count == 7, "la semana completa, con descansos")
        #expect(app.goals.weekOutcomes.map(\.weekday) == (0...6).map { PlannedDay.weekday(atPosition: $0) },
                "la semana día por día también va de lunes a domingo")
    }

    @Test("La sesión de hoy no se marca como fallada: el día no ha terminado")
    func todayIsNotJudgedYet() async {
        // Se fuerza el plan a caer **hoy** con `preferredWeekdays`, en vez de esperar a que el
        // reparto lo ponga ahí: así la prueba dice lo mismo cualquier día que corra. La anterior
        // pasaba en local y fallaba en CI justo por depender del día.
        let today = cal.component(.weekday, from: Date())
        let app = TestApp(goals: [volumeGoal()])
        await app.start()
        app.goals.planConfig = PlanConfig(daysPerWeek: 1, preferredWeekdays: [today])

        let outcome = app.goals.weekOutcomes.first { $0.weekday == today }
        #expect(outcome?.plannedKm ?? 0 > 0, "el plan debía caer hoy")
        #expect(outcome?.doneKm == 0)
        #expect(outcome?.status == .upcoming, "todavía puedes salir a correr")
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

    // MARK: - Los días/semana salen del historial, no de un número inventado

    /// Corridas en `daysPerWeek` días distintos de cada una de las `weeks` **semanas de calendario**
    /// anteriores a la actual.
    ///
    /// Alineado a semanas y no a bloques de `daysAgo`: `SuggestPlanUseCase` agrupa por
    /// `weekOfYear`, así que contar días hacia atrás desde hoy parte el bloque en dos semanas
    /// cuando hoy cae cerca del borde — y el promedio sale más bajo unos días de la semana que
    /// otros. Semanas completas y pasadas, además, evitan los días futuros (que no cuentan).
    private func history(daysPerWeek: Int, weeks: Int) -> [TrainingSession] {
        let thisWeek = Calendar.app.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (1...weeks).flatMap { weeksBack -> [TrainingSession] in
            let start = cal.date(byAdding: .day, value: -7 * weeksBack, to: thisWeek) ?? thisWeek
            return (0..<daysPerWeek).map { day in
                TrainingSession(date: cal.date(byAdding: .day, value: day, to: start) ?? start,
                                type: .running, title: "Histórico",
                                distanceKm: 8, completed: true)
            }
        }
    }

    @Test("La primera config sale del historial, no del 3 de fábrica")
    func firstConfigComesFromHistory() async {
        // El resto del plan ya sale de datos reales (volumen, tirada larga, carreras); la
        // frecuencia era lo único adivinado, y es la que decide la estructura de la semana.
        let app = TestApp(goals: [volumeGoal()], sessions: history(daysPerWeek: 5, weeks: 4))
        await app.start()
        #expect(app.goals.planConfig.daysPerWeek == 3, "arranca en el default")
        // Se comprueba primero el dato de entrada: si el historial de la prueba no representa 5
        // días/semana, el fallo es del montaje y no de la siembra, y conviene que lo diga.
        #expect(app.goals.planSuggestion()?.config.daysPerWeek == 5, "historial mal construido")

        app.goals.seedPlanConfigIfNeeded()

        #expect(app.goals.planConfig.daysPerWeek == 5, "corre 5 días: el plan debe pedir 5")
        // No se comprueba `days.count == 5`: si la semana ya empezó, el plan solo propone los días
        // que quedan. Eso es materia de otra prueba.
    }

    @Test("Sin historial suficiente se queda en el default en vez de inventar")
    func noHistoryKeepsTheDefault() async {
        let app = TestApp(goals: [volumeGoal()], sessions: [session(.running, km: 8, daysAgo: 2)])
        await app.start()

        app.goals.seedPlanConfigIfNeeded()

        #expect(app.goals.planConfig.daysPerWeek == 3, "una sola corrida no da para inferir nada")
    }

    @Test("No pisa lo que ya elegiste, ni aunque coincida con el default")
    func doesNotOverwriteAChosenConfig() async {
        let app = TestApp(goals: [volumeGoal()], sessions: history(daysPerWeek: 6, weeks: 4))
        await app.start()
        // Elegir 3 a mano es una decisión, no la ausencia de una: no se puede distinguir por el
        // valor, solo por si hay algo guardado.
        app.goals.planConfig = PlanConfig(daysPerWeek: 3)

        app.goals.seedPlanConfigIfNeeded()

        #expect(app.goals.planConfig.daysPerWeek == 3)
    }

    @Test("Sembrar es idempotente: no vuelve a tocar la config en arranques siguientes")
    func seedingIsIdempotent() async {
        let app = TestApp(goals: [volumeGoal()], sessions: history(daysPerWeek: 4, weeks: 4))
        await app.start()
        app.goals.seedPlanConfigIfNeeded()
        #expect(app.goals.planConfig.daysPerWeek == 4)

        // El atleta baja a 2 días; una siembra posterior no debe deshacerlo.
        app.goals.planConfig = PlanConfig(daysPerWeek: 2)
        app.goals.seedPlanConfigIfNeeded()

        #expect(app.goals.planConfig.daysPerWeek == 2)
    }

    @Test("Sembrar no te crea una meta de volumen a tus espaldas")
    func seedingDoesNotCreateGoals() async {
        // `applyPlanSuggestion` sí la crea, pero eso lo pediste tú tocando «Aplicar». Ajustar los
        // días es reversible con un stepper; que te aparezca una meta que no pusiste, no.
        let app = TestApp(sessions: history(daysPerWeek: 5, weeks: 4))
        await app.start()

        app.goals.seedPlanConfigIfNeeded()

        #expect(app.goals.planConfig.daysPerWeek == 5)
        #expect(app.goalRepo.added.isEmpty)
        #expect(app.goalRepo.updated.isEmpty)
    }

    // MARK: - La semana ya empezada

    /// Fecha de esta semana en la posición dada (0 = lunes … 6 = domingo).
    private func thisWeek(position: Int) -> Date {
        let start = Calendar.app.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return Calendar.app.date(byAdding: .day, value: position, to: start) ?? start
    }

    private var todayPosition: Int {
        PlannedDay.position(of: cal.component(.weekday, from: Date()))
    }

    @Test("El plan no propone días que ya pasaron")
    func doesNotPlanThePast() async {
        let app = TestApp(goals: [volumeGoal()], sessions: history(daysPerWeek: 3, weeks: 3))
        await app.start()
        guard let plan = app.goals.currentPlan else {
            Issue.record("hace falta un plan")
            return
        }
        // Es el caso que motivó todo: planificar un sábado y que el plan te pida el martes — y
        // luego te lo marque fallado. Un día que ya pasó no es una sugerencia, es un reproche.
        for day in plan.days {
            #expect(day.weekPosition >= todayPosition,
                    "propone \(day.label) en una posición ya pasada (\(day.weekPosition))")
        }
        #expect(plan.plansFrom == todayPosition)
    }

    @Test("Los días previos al plan no salen como fallados ni como extra")
    func daysBeforeThePlanAreNotJudged() async {
        // Se corre en el primer día de la semana, que siempre ha pasado o es hoy.
        let app = TestApp(goals: [volumeGoal()], sessions: [
            TrainingSession(date: thisWeek(position: 0), type: .running,
                            title: "Lunes", distanceKm: 8, completed: true)
        ])
        await app.start()
        guard let outcome = app.goals.weekOutcomes.first(where: {
            PlannedDay.position(of: $0.weekday) == 0
        }) else {
            Issue.record("la semana día por día debe cubrir los 7 días")
            return
        }
        if todayPosition > 0 {
            #expect(outcome.status == .done, "corriste ese día: cuenta como hecho, no como extra")
        }
    }

    @Test("Si ya corriste hoy, el plan no te pide otra sesión hoy")
    func todaysRunIsNotAskedAgain() async {
        // **Hoy** y no un día pasado: los pasados ya los descarta la regla de "no planificar el
        // pasado", así que una prueba sobre ellos no distingue las dos reglas — comprobado por
        // mutación, quitar el descarte por día entrenado no la hacía fallar.
        let today = cal.component(.weekday, from: Date())
        let app = TestApp(goals: [volumeGoal()], sessions: [
            TrainingSession(date: Date(), type: .running,
                            title: "Ya corrí hoy", distanceKm: 8, completed: true)
        ])
        await app.start()
        guard let plan = app.goals.currentPlan else { return }

        #expect(!plan.days.contains { $0.weekday == today },
                "pide otra sesión un día en el que ya corriste")
    }

    @Test("Los km ya corridos salen del presupuesto de la semana, no se suman encima")
    func alreadyRunKmComeOutOfTheBudget() async {
        let sinNada = TestApp(goals: [volumeGoal()], sessions: [])
        await sinNada.start()
        let base = sinNada.goals.currentPlan?.totalKm ?? 0

        let conCorridas = TestApp(goals: [volumeGoal()], sessions: [
            TrainingSession(date: thisWeek(position: 0), type: .running,
                            title: "Lunes", distanceKm: 10, completed: true)
        ])
        await conCorridas.start()
        let pedido = conCorridas.goals.currentPlan?.totalKm ?? 0

        // Con 10 km ya hechos, la semana pide **menos** de lo que pediría sin ellos.
        if todayPosition > 0 { #expect(pedido <= base) }
    }

    @Test("Cuando no caben las sesiones en los días que quedan, se dice")
    func warnsWhenSessionsDoNotFitInTheRemainingDays() async {
        // El caso del domingo: la semana pide 4 sesiones y solo queda un día. Antes se mostraba
        // "1 día · 6 km" de una semana de 45 km, sin decir por qué — el `unfit` de `allocate` no lo
        // ve, porque ese mira los topes de sesión y no cuántos días quedan.
        let app = TestApp(goals: [volumeGoal()], sessions: history(daysPerWeek: 4, weeks: 3))
        await app.start()
        app.goals.planConfig = PlanConfig(daysPerWeek: 4)

        guard let plan = app.goals.currentPlan else { return }
        let quedan = 7 - plan.plansFrom
        if quedan < 4 {
            #expect(plan.note != nil, "se pierden sesiones y no se avisa")
            #expect(plan.note?.contains("próxima") == true, "y se dice a dónde ir: \(plan.note ?? "")")
        }
        // La semana que viene está entera, así que ahí no debe avisar de esto.
        #expect(app.goals.plan(weekOffset: 1)?.note?.contains("quedan pocos días") != true)
    }

    @Test("Los km del pasado salen de lo que corriste, no de lo que se había planeado")
    func pastDaysReportWhatYouActuallyRan() async {
        let app = TestApp(goals: [volumeGoal()], sessions: [
            TrainingSession(date: thisWeek(position: 0), type: .running,
                            title: "Lunes", distanceKm: 7.5, completed: true),
            TrainingSession(date: thisWeek(position: 0), type: .running,
                            title: "Lunes doble", distanceKm: 2.5, completed: true),
            TrainingSession(date: thisWeek(position: 0), type: .walking,
                            title: "Caminata", distanceKm: 30, completed: true)
        ])
        await app.start()
        guard let plan = app.goals.currentPlan else { return }

        let done = app.goals.doneKmByWeekday(for: plan)
        let lunes = PlannedDay.weekday(atPosition: 0)
        // Dos carreras el mismo día suman; la caminata no cuenta, igual que en el volumen del plan.
        #expect(done[lunes] == 10)
    }

    // MARK: - Planificar la semana que viene

    @Test("La semana que viene se planifica entera, no solo los días que quedan de esta")
    func nextWeekIsPlannedInFull() async {
        let app = TestApp(goals: [volumeGoal()], sessions: history(daysPerWeek: 4, weeks: 3))
        await app.start()
        app.goals.planConfig = PlanConfig(daysPerWeek: 4)

        let next = app.goals.plan(weekOffset: 1)
        #expect(next?.plansFrom == 0, "la semana que viene no ha empezado")
        #expect(next?.days.count == 4, "caben los 4 días pedidos")
    }

    @Test("El plan de la semana que viene arranca el lunes siguiente")
    func nextWeekStartsNextMonday() async {
        let app = TestApp(goals: [volumeGoal()], sessions: [])
        await app.start()
        guard let thisOne = app.goals.plan(weekOffset: 0),
              let nextOne = app.goals.plan(weekOffset: 1) else { return }

        let days = Calendar.app.dateComponents([.day], from: thisOne.weekStart,
                                               to: nextOne.weekStart).day
        #expect(days == 7)
        #expect(cal.component(.weekday, from: nextOne.weekStart) == 2, "lunes")
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
