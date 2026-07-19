import Foundation
import FirebaseFirestore

/// Mapeo entre `RecoveryCheckIn` y su documento de Firestore.
enum RecoveryCheckInDTO {

    /// Id del documento: la fecha en formato yyyy-MM-dd (un check-in por día).
    static func documentID(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func toFirestore(_ checkIn: RecoveryCheckIn) -> [String: Any] {
        var dict: [String: Any] = [
            "date": Timestamp(date: checkIn.date),
            "feeling": checkIn.feeling,
            "predictedRemainingHours": checkIn.predictedRemainingHours
        ]
        dict["hrv"] = checkIn.hrv
        dict["baselineHRV"] = checkIn.baselineHRV
        dict["sleepHours"] = checkIn.sleepHours
        dict["loadMinutes"] = checkIn.loadMinutes
        return dict
    }

    static func toDomain(_ data: [String: Any]) -> RecoveryCheckIn? {
        guard let timestamp = data["date"] as? Timestamp,
              let feeling = data["feeling"] as? Int else { return nil }
        return RecoveryCheckIn(
            date: Calendar.current.startOfDay(for: timestamp.dateValue()),
            feeling: feeling,
            predictedRemainingHours: data["predictedRemainingHours"] as? Int ?? 0,
            hrv: data["hrv"] as? Double,
            baselineHRV: data["baselineHRV"] as? Double,
            sleepHours: data["sleepHours"] as? Double,
            loadMinutes: data["loadMinutes"] as? Int
        )
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}
