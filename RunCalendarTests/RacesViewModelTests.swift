import Foundation
import Testing
@testable import RunCalendar

/// `RacesViewModel` — el gasto del año y el porqué de un clima ausente.
///
/// `.serialized` porque las claves del calendario viven en `UserDefaults`, que es global.
@Suite("RacesViewModel · gasto y clima", .serialized)
@MainActor
struct RacesViewModelTests {

    private let cal = Calendar.current

    /// Carrera de este año, `monthsFromNow` meses adelante. Con coordenadas por defecto: sin ellas
    /// el ViewModel geocodifica de verdad contra la red, y una prueba no puede depender de eso.
    private func race(_ name: String = "Carrera", cost: Decimal? = nil, currency: String = "MXN",
                      registered: Bool = true, monthOffset: Int = 1,
                      located: Bool = true, kit: KitPickup? = nil) -> Race {
        Race(
            name: name,
            date: cal.date(byAdding: .month, value: monthOffset, to: startOfYear) ?? Date(),
            location: located
                ? RaceLocation(name: "Ciudad", address: "Calle 1", latitude: 19.4, longitude: -99.1)
                : RaceLocation(name: "", address: ""),
            cost: cost,
            currency: currency,
            kitPickup: kit,
            isRegistered: registered
        )
    }

    private var startOfYear: Date {
        cal.date(from: DateComponents(year: cal.component(.year, from: Date()), month: 1, day: 1)) ?? Date()
    }

    // MARK: - Gasto

    @Test("Solo cuentan las carreras inscritas y con costo")
    func spendingCountsRegisteredWithCostOnly() async {
        let app = TestApp(races: [
            race("Inscrita", cost: 800),
            race("Solo la estoy viendo", cost: 1200, registered: false),
            race("Inscrita sin costo capturado", cost: nil)
        ])
        await app.start()

        let spending = app.races.spendingThisYear
        #expect(spending?.count == 1)
        #expect(spending?.totals.first?.amount == 800)
    }

    @Test("El gasto se agrupa por moneda, no se suman pesos con dólares")
    func spendingGroupsByCurrency() async {
        let app = TestApp(races: [
            race("Local", cost: 800, currency: "MXN", monthOffset: 1),
            race("Otra local", cost: 1200, currency: "MXN", monthOffset: 2),
            race("Fuera", cost: 90, currency: "USD", monthOffset: 3)
        ])
        await app.start()

        let totals = app.races.spendingThisYear?.totals ?? []
        #expect(totals.count == 2)
        // Ordenadas de mayor a menor **por importe**, que es lo que se lee primero.
        #expect(totals.first?.currency == "MXN")
        #expect(totals.first?.amount == 2000)
        #expect(totals.last?.amount == 90)
    }

    @Test("Sin carreras pagadas no se muestra la tarjeta de gasto")
    func noSpendingCardWhenNothingPaid() async {
        let app = TestApp(races: [race("Sin costo")])
        await app.start()
        #expect(app.races.spendingThisYear == nil)
    }

    @Test("El desglose por mes agrupa las del mismo mes")
    func spendingBreaksDownByMonth() async {
        let app = TestApp(races: [
            race("Una", cost: 500, monthOffset: 2),
            race("Dos", cost: 700, monthOffset: 2),
            race("Tres", cost: 300, monthOffset: 5)
        ])
        await app.start()

        let months = app.races.spendingThisYear?.months ?? []
        #expect(months.count == 2)
        #expect(months.first?.races.count == 2)
        #expect(months.first?.totals.first?.amount == 1200)
    }

    // MARK: - Clima: por qué no hay dato

    /// El motivo del fallo, o `nil` si sí hubo clima. `RaceWeather` no es `Equatable`, así que el
    /// `Result` completo no se puede comparar de un golpe.
    private func reason(_ result: Result<RaceWeather, WeatherUnavailable>) -> WeatherUnavailable? {
        if case .failure(let reason) = result { return reason }
        return nil
    }

    @Test("Sin ubicación se pide capturarla, no se dice 'no se pudo'")
    func weatherWithoutLocationAsksForIt() async {
        let app = TestApp(races: [])
        await app.start()
        // Nombre y dirección vacíos: no hay nada que geocodificar (tampoco toca la red).
        let result = await app.races.weather(for: race(located: false))
        #expect(reason(result) == .noLocation)
    }

    @Test("Con ubicación pero sin datos para esa fecha, el motivo es la fecha")
    func weatherWithoutDataForDate() async {
        let app = TestApp(races: [])
        await app.start()
        app.weatherRepo.result = nil        // la API no cubre fechas tan lejanas

        let result = await app.races.weather(for: race(monthOffset: 10))
        #expect(reason(result) == .noDataForDate)
    }

    @Test("Si el servicio falla, el motivo es el servicio — no la carrera del usuario")
    func weatherServiceFailure() async {
        let app = TestApp(races: [])
        await app.start()
        app.weatherRepo.failure = FakeFailure()

        let result = await app.races.weather(for: race())
        #expect(reason(result) == .serviceUnreachable)
    }

    @Test("Con coordenadas y datos, devuelve el clima")
    func weatherSuccess() async {
        let app = TestApp(races: [])
        await app.start()
        app.weatherRepo.result = RaceWeather(
            temperatureC: 18, apparentTemperatureC: 17, humidity: 60, windKmh: 8,
            precipitationProbability: 10, condition: .clear, kind: .forecast
        )

        guard case .success(let weather) = await app.races.weather(for: race()) else {
            Issue.record("con coordenadas y datos debía haber clima")
            return
        }
        #expect(weather.temperatureC == 18)
    }

    // MARK: - Calendario

    @Test("Agregar al calendario recuerda la carrera para no duplicarla")
    func addingToCalendarRemembers() async {
        let app = TestApp(races: [])
        await app.start()
        let target = race("Maratón")

        #expect(app.races.isInCalendar(target) == false)
        let ok = await app.races.addRaceToCalendar(target)

        #expect(ok)
        #expect(app.races.isInCalendar(target), "el botón debe cambiar a «ya está en tu calendario»")
        #expect(app.calendarRepo.events.first?.title == "Maratón")
        // El acceso a EventKit es solo-escritura: no se puede consultar el calendario real, así
        // que la única defensa contra duplicar es acordarse aquí.
        #expect(app.calendarRepo.events.first?.alarmMinutesBefore == 24 * 60)
    }

    @Test("La entrega de kit es un evento aparte del de la carrera")
    func kitPickupIsItsOwnEvent() async {
        let app = TestApp(races: [])
        await app.start()
        let target = race("Medio", kit: KitPickup(date: Date(), location: nil, notes: "Lleva INE"))

        _ = await app.races.addRaceToCalendar(target)
        _ = await app.races.addKitPickupToCalendar(target)

        #expect(app.calendarRepo.events.count == 2)
        #expect(app.races.isInCalendar(target))
        #expect(app.races.isKitInCalendar(target))
    }

    @Test("Una carrera sin fecha de kit no agrega nada")
    func noKitDateNoEvent() async {
        let app = TestApp(races: [])
        await app.start()

        let ok = await app.races.addKitPickupToCalendar(race("Sin kit"))

        #expect(ok == false)
        #expect(app.calendarRepo.events.isEmpty)
    }

    @Test("Si el calendario rechaza el permiso, el error llega a la vista")
    func calendarPermissionDeniedSurfaces() async {
        let app = TestApp(races: [])
        await app.start()
        app.calendarRepo.failure = FakeFailure()
        let target = race("Con permiso negado")

        let ok = await app.races.addRaceToCalendar(target)

        #expect(ok == false)
        #expect(app.races.errorMessage != nil)
        #expect(app.races.isInCalendar(target) == false, "no se recuerda lo que no se guardó")
    }
}
