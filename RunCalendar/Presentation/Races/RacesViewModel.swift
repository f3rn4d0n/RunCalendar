import Foundation
import Observation
import CoreLocation

/// Total gastado en una moneda.
struct CurrencyTotal: Identifiable {
    let currency: String
    let amount: Decimal
    var id: String { currency }
}

/// Gasto de un mes concreto.
struct MonthlySpending: Identifiable {
    let month: Int          // 1–12
    let name: String
    let totals: [CurrencyTotal]
    let races: [Race]
    var id: Int { month }
}

/// Resumen de gasto en carreras inscritas de un año, con desglose por mes.
struct SpendingSummary {
    let year: Int
    let count: Int
    let totals: [CurrencyTotal]
    let months: [MonthlySpending]
}

@MainActor
@Observable
final class RacesViewModel {

    private(set) var races: [Race] = []
    var errorMessage: String?
    private var hasStarted = false

    let userID: String
    private let observeRaces: ObserveRacesUseCase
    private let addRace: AddRaceUseCase
    private let updateRace: UpdateRaceUseCase
    private let deleteRace: DeleteRaceUseCase
    private let fetchWeather: FetchRaceWeatherUseCase
    private let addToCalendar: AddToCalendarUseCase

    init(
        userID: String,
        observeRaces: ObserveRacesUseCase,
        addRace: AddRaceUseCase,
        updateRace: UpdateRaceUseCase,
        deleteRace: DeleteRaceUseCase,
        fetchWeather: FetchRaceWeatherUseCase,
        addToCalendar: AddToCalendarUseCase
    ) {
        self.userID = userID
        self.observeRaces = observeRaces
        self.addRace = addRace
        self.updateRace = updateRace
        self.deleteRace = deleteRace
        self.fetchWeather = fetchWeather
        self.addToCalendar = addToCalendar
    }

    /// Clima del día de la carrera. Si la carrera no tiene coordenadas (p. ej. una próxima
    /// que aún no se corre), geocodifica la dirección de la sección Ubicación al vuelo.
    /// `nil` si no se pudo ubicar o la API no devolvió datos.
    func weather(for race: Race) async -> RaceWeather? {
        var latitude = race.location.latitude
        var longitude = race.location.longitude
        if latitude == nil || longitude == nil, let coordinate = await geocode(race.location) {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
        }
        do {
            return try await fetchWeather(latitude: latitude, longitude: longitude, date: race.date)
        } catch {
            Log.races.error("weather: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    var upcomingRaces: [Race] { races.filter { $0.status == .upcoming } }
    var completedRaces: [Race] { races.filter { $0.status == .completed } }

    /// Gasto en carreras **inscritas** con costo del año en curso, con desglose
    /// por mes y agrupado por moneda. `nil` si no hay ninguna.
    var spendingThisYear: SpendingSummary? {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let paid = races.filter {
            $0.isRegistered && $0.cost != nil && calendar.component(.year, from: $0.date) == year
        }
        guard !paid.isEmpty else { return nil }

        let months = Dictionary(grouping: paid) { calendar.component(.month, from: $0.date) }
            .map { month, racesInMonth in
                MonthlySpending(
                    month: month,
                    name: racesInMonth[0].date.formatted(.dateTime.month(.wide)).capitalized,
                    totals: currencyTotals(racesInMonth),
                    races: racesInMonth.sorted { $0.date < $1.date }
                )
            }
            .sorted { $0.month < $1.month }

        return SpendingSummary(year: year, count: paid.count, totals: currencyTotals(paid), months: months)
    }

    /// Suma de costos agrupada por moneda (mayor a menor).
    private func currencyTotals(_ races: [Race]) -> [CurrencyTotal] {
        var byCurrency: [String: Decimal] = [:]
        for race in races {
            byCurrency[race.currency, default: 0] += race.cost ?? 0
        }
        return byCurrency
            .sorted { $0.value > $1.value }
            .map { CurrencyTotal(currency: $0.key, amount: $0.value) }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        for await items in observeRaces(userID: userID) {
            races = items
        }
    }

    func save(_ race: Race, isNew: Bool) async -> Bool {
        var race = race
        // Sin coordenadas → geocodifica la dirección para poder mostrar el clima.
        // Si falla (offline, dirección vaga), se guarda igual sin coordenadas.
        if race.location.latitude == nil, race.location.longitude == nil,
           let coordinate = await geocode(race.location) {
            race.location.latitude = coordinate.latitude
            race.location.longitude = coordinate.longitude
        }
        do {
            if isNew {
                try await addRace(race, userID: userID)
            } else {
                try await updateRace(race, userID: userID)
            }
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Agrega la carrera al calendario del sistema. Devuelve si tuvo éxito.
    func addRaceToCalendar(_ race: Race) async -> Bool {
        var notes = race.notes
        if let bib = race.bibNumber, !bib.isEmpty {
            notes = notes.isEmpty ? "Dorsal: \(bib)" : notes + "\nDorsal: \(bib)"
        }
        // Sin duración conocida: bloque de 2 h desde la hora del evento.
        return await add(CalendarEvent(
            title: race.name,
            startDate: race.date,
            endDate: race.date.addingTimeInterval(2 * 3600),
            location: locationText(race.location),
            notes: notes.isEmpty ? nil : notes
        ))
    }

    /// Agrega la entrega de kit al calendario. `false` si el kit no tiene fecha.
    func addKitPickupToCalendar(_ race: Race) async -> Bool {
        guard let kit = race.kitPickup, let date = kit.date else { return false }
        return await add(CalendarEvent(
            title: "Entrega de kit — \(race.name)",
            startDate: date,
            endDate: date.addingTimeInterval(3600),
            location: kit.location.flatMap(locationText),
            notes: kit.notes.isEmpty ? nil : kit.notes
        ))
    }

    private func add(_ event: CalendarEvent) async -> Bool {
        do {
            try await addToCalendar(event)
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Texto de ubicación "Nombre, Dirección" (omite lo vacío).
    private func locationText(_ location: RaceLocation) -> String? {
        let parts = [location.name, location.address].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Coordenadas del lugar a partir de su dirección (o nombre si no hay dirección).
    private func geocode(_ location: RaceLocation) async -> CLLocationCoordinate2D? {
        let query = location.address.isEmpty ? location.name : location.address
        guard !query.isEmpty else { return nil }
        let placemarks = try? await CLGeocoder().geocodeAddressString(query)
        return placemarks?.first?.location?.coordinate
    }

    func delete(_ race: Race) async {
        do {
            try await deleteRace(raceID: race.id, userID: userID)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
