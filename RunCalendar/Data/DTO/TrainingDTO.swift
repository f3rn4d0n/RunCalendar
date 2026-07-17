import Foundation
import FirebaseFirestore

/// Mapeo entre `TrainingSession` (dominio) y el documento de Firestore.
enum TrainingDTO {

    static func toFirestore(_ session: TrainingSession) -> [String: Any] {
        var dict: [String: Any] = [
            "date": Timestamp(date: session.date),
            "type": session.type.rawValue,
            "title": session.title,
            "details": session.details,
            "completed": session.completed,
            "notes": session.notes
        ]
        dict["durationMin"] = session.durationMin
        dict["distanceKm"] = session.distanceKm
        dict["targetPace"] = session.targetPace
        dict["avgHeartRate"] = session.avgHeartRate
        dict["wod"] = session.wod
        dict["isPriority"] = session.isPriority
        dict["targetRaceID"] = session.targetRaceID
        return dict
    }

    static func toDomain(id: String, data: [String: Any]) -> TrainingSession? {
        guard
            let timestamp = data["date"] as? Timestamp,
            let title = data["title"] as? String
        else { return nil }

        return TrainingSession(
            id: id,
            date: timestamp.dateValue(),
            type: TrainingType(rawValue: data["type"] as? String ?? "") ?? .running,
            title: title,
            details: data["details"] as? String ?? "",
            durationMin: data["durationMin"] as? Int,
            distanceKm: data["distanceKm"] as? Double,
            targetPace: data["targetPace"] as? String,
            avgHeartRate: data["avgHeartRate"] as? Int,
            wod: data["wod"] as? String,
            completed: data["completed"] as? Bool ?? false,
            notes: data["notes"] as? String ?? "",
            isPriority: data["isPriority"] as? Bool ?? false,
            targetRaceID: data["targetRaceID"] as? String
        )
    }
}
