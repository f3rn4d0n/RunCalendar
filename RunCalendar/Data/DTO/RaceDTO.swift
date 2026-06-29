import Foundation
import FirebaseFirestore

/// Mapeo entre `Race` (dominio) y el documento de Firestore.
/// Se usa diccionario `[String: Any]` para controlar los tipos nativos de Firestore (Timestamp).
enum RaceDTO {

    static func toFirestore(_ race: Race) -> [String: Any] {
        var dict: [String: Any] = [
            "name": race.name,
            "date": Timestamp(date: race.date),
            "discipline": race.discipline.rawValue,
            "locationName": race.location.name,
            "locationAddress": race.location.address,
            "currency": race.currency,
            "notes": race.notes,
            "status": race.status.rawValue
        ]
        dict["distanceKm"] = race.distanceKm
        dict["latitude"] = race.location.latitude
        dict["longitude"] = race.location.longitude
        dict["cost"] = race.cost.map { NSDecimalNumber(decimal: $0).doubleValue }
        dict["registrationURL"] = race.registrationURL?.absoluteString

        if let kit = race.kitPickup {
            var kitDict: [String: Any] = ["notes": kit.notes]
            kitDict["date"] = kit.date.map { Timestamp(date: $0) }
            kitDict["locationName"] = kit.location?.name
            kitDict["locationAddress"] = kit.location?.address
            dict["kitPickup"] = kitDict
        }
        return dict
    }

    static func toDomain(id: String, data: [String: Any]) -> Race? {
        guard
            let name = data["name"] as? String,
            let timestamp = data["date"] as? Timestamp
        else { return nil }

        let location = RaceLocation(
            name: data["locationName"] as? String ?? "",
            address: data["locationAddress"] as? String ?? "",
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double
        )

        var kitPickup: KitPickup?
        if let kitDict = data["kitPickup"] as? [String: Any] {
            let kitLocationName = kitDict["locationName"] as? String
            let kitLocation = kitLocationName.map {
                RaceLocation(name: $0, address: kitDict["locationAddress"] as? String ?? "")
            }
            kitPickup = KitPickup(
                date: (kitDict["date"] as? Timestamp)?.dateValue(),
                location: kitLocation,
                notes: kitDict["notes"] as? String ?? ""
            )
        }

        let cost = (data["cost"] as? Double).map { Decimal($0) }
        let url = (data["registrationURL"] as? String).flatMap(URL.init(string:))

        return Race(
            id: id,
            name: name,
            date: timestamp.dateValue(),
            discipline: RaceDiscipline(rawValue: data["discipline"] as? String ?? "") ?? .other,
            distanceKm: data["distanceKm"] as? Double,
            location: location,
            cost: cost,
            currency: data["currency"] as? String ?? "MXN",
            registrationURL: url,
            kitPickup: kitPickup,
            notes: data["notes"] as? String ?? "",
            status: RaceStatus(rawValue: data["status"] as? String ?? "") ?? .upcoming
        )
    }
}
