import Foundation
import Testing
@testable import RunCalendar

/// `HealthViewModel` — disponibilidad, autorización, y el `.loaded` compuesto (sesiones
/// registradas vs. Salud cruda) que alimenta recuperación y ACWR.
///
/// `.serialized`: `TestApp` arma también `RacesViewModel`/`GoalsViewModel`, que leen `UserDefaults`.
@Suite("HealthViewModel · disponibilidad, carga y check-in", .serialized)
@MainActor
struct HealthViewModelTests {

    // MARK: - Disponibilidad

    @Test("Sin Salud disponible el estado es unavailable, no loading")
    func unavailableWhenHealthNotAvailable() {
        let app = TestApp(healthAvailable: false)
        #expect(app.health.state == .unavailable)
        #expect(app.health.isHealthAvailable == false)
    }

    @Test("Con Salud disponible arranca en loading, sin esperar a connect()")
    func startsLoadingWhenAvailable() {
        let app = TestApp(healthAvailable: true)
        #expect(app.health.state == .loading)
    }

    @Test("En un dispositivo sin Salud, connect() no intenta cargar")
    func connectNoOpWhenUnavailable() async {
        let app = TestApp(healthAvailable: false)
        await app.health.connect()
        #expect(app.health.state == .unavailable)
    }

    @Test("Si el usuario niega el permiso, el estado pasa a error (no a unavailable)")
    func deniedAuthorizationSurfacesError() async {
        let app = TestApp(healthAvailable: true)
        app.healthRepo.grantsAuthorization = false

        await app.health.connect()

        guard case .error = app.health.state else {
            Issue.record("se esperaba .error cuando se niega el permiso, no \(app.health.state)")
            return
        }
    }

    // MARK: - Carga: sesiones registradas mandan sobre Salud cruda

    @Test("Sin sesiones registradas, la carga sale del workload crudo de Salud")
    func workloadFallsBackToHealthKitWithoutSessions() async {
        let app = TestApp(healthAvailable: true)
        // 400/4 = 100 semanal; 140/100 = 1.4 → precaución.
        app.healthRepo.workload = WorkloadInput(acuteMinutes: 140, chronicMinutes: 400)

        await app.health.connect()

        guard case .loaded(let data) = app.health.state else {
            Issue.record("se esperaba .loaded"); return
        }
        #expect(data.workload?.zone == .caution)
    }

    @Test("Con sesiones registradas, su carga (RPE × min) manda sobre el workload crudo de Salud")
    func sessionLoadOverridesHealthKitWorkload() async {
        let now = Date()
        let sessions = (0..<3).map { i in
            TrainingSession(date: now.addingTimeInterval(-Double(i) * 86_400), type: .running,
                            title: "Rodaje", durationMin: 60, completed: true, rpe: 5)
        }
        let app = TestApp(sessions: sessions, healthAvailable: true)
        // Si el ViewModel tomara esto en vez de las sesiones, el resultado sería otro.
        app.healthRepo.workload = WorkloadInput(acuteMinutes: 1, chronicMinutes: 4_000)

        await app.health.connect()

        guard case .loaded(let data) = app.health.state else {
            Issue.record("se esperaba .loaded"); return
        }
        // 3 sesiones de 60 min a RPE 5 (= minutos crudos), todas dentro de 7 días → 180 min agudos.
        #expect(data.workload?.acuteMinutes == 180)
    }

    // MARK: - Readiness

    @Test("Sin datos cargados, readiness(for:) no arriesga un número")
    func readinessNilBeforeLoad() {
        let app = TestApp(healthAvailable: false)
        let race = Race(name: "10K", date: Date(), location: RaceLocation(name: "Ciudad"))
        #expect(app.health.readiness(for: race) == nil)
    }

    @Test("Cargado, readiness(for:) devuelve el nivel de la distancia que corresponde a la carrera")
    func readinessMatchesRaceDistance() async {
        let app = TestApp(healthAvailable: true)
        app.healthRepo.summary = FitnessSummary(
            weeks: 8, totalDistanceKm: 200, weeklyDistanceKm: 25, last7DaysKm: 25,
            longestRunKm: 10, runCount: 10, lastRunDate: Date(), vo2Max: nil,
            restingHeartRate: nil, age: nil
        )
        await app.health.connect()

        let race = Race(name: "10K", date: Date(), discipline: .tenK, location: RaceLocation(name: "Ciudad"))
        let result = app.health.readiness(for: race)
        #expect(result?.distance == .tenK)
        #expect(result?.level == .ready, "long run de 10 km ya cubre una 10K")
    }

    // MARK: - Check-in de recuperación

    @Test("Guardar un check-in lo refleja de inmediato y lo persiste")
    func submitCheckInPersistsAndUpdatesToday() async {
        let app = TestApp(healthAvailable: true)
        app.healthRepo.recovery = RecoverySnapshot(
            currentHRV: 55, baselineHRV: 60, restingHR: 50, baselineRestingHR: 48,
            recentLoadMinutes: 90, hoursSinceLastWorkout: 10, lastNightSleepHours: 7
        )
        await app.health.connect()

        await app.health.submitCheckIn(feeling: 4)

        #expect(app.health.todayCheckIn?.feeling == 4)
        #expect(app.recoveryLogRepo.checkIns.count == 1)
        #expect(app.health.recentCheckIns.count == 1)
    }

    @Test("Un segundo check-in el mismo día reemplaza al primero, no lo duplica")
    func secondCheckInSameDayReplaces() async {
        let app = TestApp(healthAvailable: true)
        await app.health.connect()

        await app.health.submitCheckIn(feeling: 2)
        await app.health.submitCheckIn(feeling: 5)

        #expect(app.health.recentCheckIns.count == 1)
        #expect(app.health.todayCheckIn?.feeling == 5)
    }

    // MARK: - onAppear / reloadIfLoaded

    @Test("onAppear no recarga si ya estaba cargado")
    func onAppearSkipsReloadWhenAlreadyLoaded() async {
        let app = TestApp(healthAvailable: true)
        app.healthRepo.summary = .empty
        await app.health.connect()
        // Si onAppear recargara, este cambio se vería reflejado.
        app.healthRepo.summary = FitnessSummary(
            weeks: 8, totalDistanceKm: 999, weeklyDistanceKm: 999, last7DaysKm: 999,
            longestRunKm: 999, runCount: 99, lastRunDate: nil, vo2Max: nil,
            restingHeartRate: nil, age: nil
        )

        await app.health.onAppear()

        guard case .loaded(let data) = app.health.state else {
            Issue.record("se esperaba seguir .loaded"); return
        }
        #expect(data.summary.totalDistanceKm == 0, "no debía recargar y pisar el estado ya cargado")
    }

    @Test("reloadIfLoaded no hace nada si aún no había una primera carga")
    func reloadIfLoadedNoOpBeforeFirstLoad() async {
        let app = TestApp(healthAvailable: true) // arranca en .loading, sin llamar a connect()
        await app.health.reloadIfLoaded()
        #expect(app.health.state == .loading)
    }
}
