import Foundation

/// Disciplina / distancia de una carrera.
enum RaceDiscipline: String, CaseIterable, Identifiable, Sendable {
    case fiveK = "5K"
    case tenK = "10K"
    case halfMarathon = "21K"
    case marathon = "42K"
    case trail = "Trail"
    case other = "Otra"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Distancia oficial en km (para ritmo/récords). `nil` en distancias variables.
    var standardDistanceKm: Double? {
        switch self {
        case .fiveK:        return 5
        case .tenK:         return 10
        case .halfMarathon: return 21.0975
        case .marathon:     return 42.195
        case .trail, .other: return nil
        }
    }
}

/// Estado de la carrera respecto a la fecha actual.
enum RaceStatus: String, CaseIterable, Identifiable, Sendable {
    case upcoming = "Próxima"
    case completed = "Completada"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

/// Ubicación de un evento (carrera o entrega de kit).
struct RaceLocation: Equatable, Sendable {
    var name: String
    var address: String
    var latitude: Double?
    var longitude: Double?

    init(name: String, address: String = "", latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Información de la entrega del kit del corredor.
struct KitPickup: Equatable, Sendable {
    var date: Date?
    var location: RaceLocation?
    var notes: String

    init(date: Date? = nil, location: RaceLocation? = nil, notes: String = "") {
        self.date = date
        self.location = location
        self.notes = notes
    }
}

/// Carrera del calendario del usuario.
struct Race: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var date: Date
    var discipline: RaceDiscipline
    var distanceKm: Double?
    var location: RaceLocation
    var cost: Decimal?
    var currency: String
    var registrationURL: URL?
    var kitPickup: KitPickup?
    var notes: String
    var status: RaceStatus

    /// Si el usuario ya se inscribió a la carrera (independiente de `status`).
    var isRegistered: Bool
    /// Número de corredor (dorsal). Texto: admite ceros a la izquierda o letras.
    var bibNumber: String?
    /// Tiempo que tardó en completarla, en segundos. Numérico para futura
    /// integración con Apple Watch / Garmin / Salud.
    var finishTimeSeconds: Int?
    /// Evento objetivo/prioritario para enfocar el entrenamiento.
    var isPriority: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        date: Date,
        discipline: RaceDiscipline = .tenK,
        distanceKm: Double? = nil,
        location: RaceLocation,
        cost: Decimal? = nil,
        currency: String = "MXN",
        registrationURL: URL? = nil,
        kitPickup: KitPickup? = nil,
        notes: String = "",
        status: RaceStatus = .upcoming,
        isRegistered: Bool = false,
        bibNumber: String? = nil,
        finishTimeSeconds: Int? = nil,
        isPriority: Bool = false
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.discipline = discipline
        self.distanceKm = distanceKm
        self.location = location
        self.cost = cost
        self.currency = currency
        self.registrationURL = registrationURL
        self.kitPickup = kitPickup
        self.notes = notes
        self.status = status
        self.isRegistered = isRegistered
        self.bibNumber = bibNumber
        self.finishTimeSeconds = finishTimeSeconds
        self.isPriority = isPriority
    }
}
