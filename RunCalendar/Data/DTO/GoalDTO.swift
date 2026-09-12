import Foundation
import FirebaseFirestore

/// Mapeo entre `Goal` (dominio) y el documento de Firestore.
enum GoalDTO {

    static func toFirestore(_ goal: Goal) -> [String: Any] {
        var dict: [String: Any] = [
            "type": goal.type.rawValue,
            "targetValue": goal.targetValue,
            "notes": goal.notes,
            "createdAt": Timestamp(date: goal.createdAt)
        ]
        dict["startValue"] = goal.startValue
        dict["distance"] = goal.distance?.rawValue
        dict["deadline"] = goal.deadline.map { Timestamp(date: $0) }
        dict["manualMissions"] = goal.manualMissions.map(missionToFirestore)
        return dict
    }

    private static func missionToFirestore(_ mission: CampaignMission) -> [String: Any] {
        ["id": mission.id, "title": mission.title, "detail": mission.detail,
         "isDone": mission.isDone, "systemImage": mission.systemImage]
    }

    private static func missionFromFirestore(_ data: [String: Any]) -> CampaignMission? {
        guard let id = data["id"] as? String, let title = data["title"] as? String else { return nil }
        return CampaignMission(id: id, title: title, detail: data["detail"] as? String ?? "",
                               isDone: data["isDone"] as? Bool ?? false,
                               systemImage: data["systemImage"] as? String ?? "square.and.pencil")
    }

    static func toDomain(id: String, data: [String: Any]) -> Goal? {
        guard
            let typeRaw = data["type"] as? String,
            let type = GoalType(rawValue: typeRaw),
            let target = data["targetValue"] as? Double
        else { return nil }

        return Goal(
            id: id,
            type: type,
            targetValue: target,
            startValue: data["startValue"] as? Double,
            distance: (data["distance"] as? String).flatMap(RaceDiscipline.init(rawValue:)),
            deadline: (data["deadline"] as? Timestamp)?.dateValue(),
            notes: data["notes"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            manualMissions: (data["manualMissions"] as? [[String: Any]] ?? []).compactMap(missionFromFirestore)
        )
    }
}
