import Foundation
import FirebaseFirestore

/// Mapea `BodyLog` ↔ Firestore. Un documento por día: `bodyLogs/{yyyy-MM-dd}`.
enum BodyLogDTO {

    /// El id del documento es el día, para que un review sobrescriba al del mismo día.
    static func documentID(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Calendar.current.startOfDay(for: date))
    }

    static func toFirestore(_ log: BodyLog) -> [String: Any] {
        [
            "date": Timestamp(date: log.date),
            "energy": log.energy,
            "hunger": log.hunger,
            "notes": log.notes
        ]
    }

    static func toDomain(_ data: [String: Any]) -> BodyLog? {
        guard let timestamp = data["date"] as? Timestamp,
              let energy = data["energy"] as? Int,
              let hunger = data["hunger"] as? Int else { return nil }
        return BodyLog(
            date: timestamp.dateValue(),
            energy: energy,
            hunger: hunger,
            notes: data["notes"] as? String ?? ""
        )
    }
}
