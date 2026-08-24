import Foundation
import Testing
@testable import RunCalendar

/// `TrainingViewModel` — filtros de sesiones, dedup contra Salud y el flujo de sincronización.
///
/// `.serialized`: `TestApp` arma también `RacesViewModel`/`GoalsViewModel`, que leen `UserDefaults`.
@Suite("TrainingViewModel · sesiones, dedup y sync con Salud", .serialized)
@MainActor
struct TrainingViewModelTests {

    private func session(_ title: String = "Sesión", type: TrainingType = .running,
                         daysAgo: Int = 0, duration: Int? = 40, completed: Bool = true,
                         rpe: Int? = nil, distanceKm: Double? = nil) -> TrainingSession {
        TrainingSession(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
            type: type, title: title, durationMin: duration, distanceKm: distanceKm,
            completed: completed, rpe: rpe
        )
    }

    // MARK: - Filtros

    @Test("sessions(of:) solo devuelve las del tipo pedido")
    func sessionsFilterByType() async {
        let app = TestApp(sessions: [
            session("Rodaje", type: .running),
            session("WOD", type: .crossfit)
        ])
        await app.training.start()
        #expect(app.training.sessions(of: .running).map(\.title) == ["Rodaje"])
    }

    @Test("sessionsNeedingRPE pide solo lo completado, con duración, sin RPE y reciente (≤14 días)")
    func sessionsNeedingRPEFiltersCorrectly() async {
        let app = TestApp(sessions: [
            session("Candidata", daysAgo: 2, rpe: nil),
            session("Ya calificada", daysAgo: 2, rpe: 6),
            session("Sin duración", daysAgo: 2, duration: nil, rpe: nil),
            session("No completada", daysAgo: 2, completed: false, rpe: nil),
            session("Muy vieja", daysAgo: 20, rpe: nil)
        ])
        await app.training.start()
        #expect(app.training.sessionsNeedingRPE.map(\.title) == ["Candidata"])
    }

    @Test("rate(_:rpe:) guarda el RPE en la sesión")
    func rateSetsRPE() async {
        let target = session("Rodaje", rpe: nil)
        let app = TestApp(sessions: [target])
        await app.training.start()

        await app.training.rate(target, rpe: 7)

        #expect(app.trainingRepo.updated.first?.rpe == 7)
    }

    // MARK: - similarSession: la misma regla de dedup que usa el import

    @Test("similarSession encuentra la sesión existente del mismo día, tipo y distancia (±10%, mínimo 0.5 km)")
    func similarSessionMatchesWithinTolerance() async {
        let existing = session("Rodaje", type: .running, daysAgo: 0, distanceKm: 10)
        let app = TestApp(sessions: [existing])
        await app.training.start()

        let candidate = session("Nueva", type: .running, daysAgo: 0, distanceKm: 10.4)
        #expect(app.training.similarSession(to: candidate)?.id == existing.id)
    }

    @Test("Distinto tipo el mismo día no cuenta como la misma actividad")
    func similarSessionRequiresSameType() async {
        let existing = session("WOD", type: .crossfit, daysAgo: 0)
        let app = TestApp(sessions: [existing])
        await app.training.start()

        let candidate = session("Rodaje", type: .running, daysAgo: 0, distanceKm: 5)
        #expect(app.training.similarSession(to: candidate) == nil)
    }

    // MARK: - Sincronización con Salud

    @Test("syncFromHealth no reimporta una carrera de Salud que ya tiene sesión parecida")
    func syncSkipsAlreadyRegisteredWorkout() async {
        let app = TestApp(sessions: [
            session("Ya la tengo", type: .running, daysAgo: 0, distanceKm: 10)
        ])
        await app.training.start()
        app.healthRepo.workouts = [
            HealthWorkout(id: "w1", type: .running, date: Date(), distanceKm: 10.05,
                         durationMin: 55, avgHeartRate: nil, cadenceSPM: nil, perceivedEffort: nil)
        ]

        await app.training.syncFromHealth()

        #expect(app.trainingRepo.added.isEmpty, "ya hay una sesión parecida, no debía duplicarse")
    }

    @Test("syncFromHealth importa una carrera de Salud sin sesión parecida, con su esfuerzo percibido")
    func syncImportsNewWorkout() async {
        let app = TestApp(sessions: [])
        await app.training.start()
        app.healthRepo.workouts = [
            HealthWorkout(id: "w2", type: .running, date: Date(), distanceKm: 5,
                         durationMin: 30, avgHeartRate: 140, cadenceSPM: 165, perceivedEffort: 6)
        ]

        await app.training.syncFromHealth()

        #expect(app.trainingRepo.added.count == 1)
        #expect(app.trainingRepo.added.first?.distanceKm == 5)
        #expect(app.trainingRepo.added.first?.rpe == 6)
    }

    @Test("syncFromHealth no reimporta dos veces el mismo workout entre llamadas")
    func syncIsIdempotentAcrossCalls() async {
        let app = TestApp(sessions: [])
        await app.training.start()
        app.healthRepo.workouts = [
            HealthWorkout(id: "w4", type: .running, date: Date(), distanceKm: 6,
                         durationMin: 35, avgHeartRate: nil, cadenceSPM: nil, perceivedEffort: nil)
        ]

        await app.training.syncFromHealth()
        await app.training.syncFromHealth()

        #expect(app.trainingRepo.added.count == 1, "el segundo sync no debe duplicar el mismo workout")
    }

    @Test("syncFromHealth rellena RPE y cadencia de una sesión ya importada, sin duplicarla")
    func syncBackfillsEffortOnExistingSession() async {
        let existing = session("Rodaje", type: .running, daysAgo: 0, distanceKm: 10, rpe: nil)
        let app = TestApp(sessions: [existing])
        await app.training.start()
        app.healthRepo.workouts = [
            HealthWorkout(id: "w5", type: .running, date: existing.date, distanceKm: 10,
                         durationMin: 55, avgHeartRate: nil, cadenceSPM: 172, perceivedEffort: 7)
        ]

        await app.training.syncFromHealth()

        #expect(app.trainingRepo.added.isEmpty, "ya existe la sesión, el backfill no importa una nueva")
        let updated = app.trainingRepo.updated.first { $0.id == existing.id }
        #expect(updated?.rpe == 7)
        #expect(updated?.cadenceSPM == 172)
    }

    // MARK: - Guardar / borrar

    @Test("toggleCompleted invierte el estado y lo guarda")
    func toggleCompletedFlipsAndSaves() async {
        let target = session("Rodaje", completed: false)
        let app = TestApp(sessions: [target])
        await app.training.start()

        await app.training.toggleCompleted(target)

        #expect(app.trainingRepo.updated.first?.completed == true)
    }

    @Test("delete borra la sesión en el repositorio")
    func deleteRemovesSession() async {
        let target = session("Rodaje")
        let app = TestApp(sessions: [target])
        await app.training.start()

        await app.training.delete(target)

        #expect(app.trainingRepo.deleted == [target.id])
    }

    @Test("Si guardar falla, el error llega a la vista")
    func saveFailureSurfacesError() async {
        let target = session("Rodaje")
        let app = TestApp(sessions: [target])
        await app.training.start()
        app.trainingRepo.failure = FakeFailure()

        await app.training.rate(target, rpe: 8)

        #expect(app.training.errorMessage != nil)
    }
}
