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
        dict["cadenceSPM"] = session.cadenceSPM
        dict["wod"] = session.wod
        dict["isPriority"] = session.isPriority
        dict["targetRaceID"] = session.targetRaceID
        dict["rpe"] = session.rpe
        // Sin condicional: con `setData(merge: true)` el arreglo se reemplaza entero, pero solo
        // si la clave viaja. Un `session.sets.isEmpty ? nil : …` haría que borrar la última serie
        // no se borrara nunca en Firestore.
        dict["sets"] = session.sets.map(setToFirestore)
        return dict
    }

    private static func setToFirestore(_ set: StrengthSet) -> [String: Any] {
        ["id": set.id, "exercise": set.exercise.rawValue, "weightKg": set.weightKg, "reps": set.reps]
    }

    private static func setFromFirestore(_ data: [String: Any]) -> StrengthSet? {
        guard
            let id = data["id"] as? String,
            let exerciseRaw = data["exercise"] as? String,
            let exercise = StrengthExercise(rawValue: exerciseRaw)
        else { return nil }
        // Como NSNumber: un peso escrito a mano en la consola de Firebase (p. ej. "100") vuelve
        // como Int, y `as? Double` fallaría en silencio.
        let weightKg = (data["weightKg"] as? NSNumber)?.doubleValue ?? 0
        let reps = (data["reps"] as? NSNumber)?.intValue ?? 0
        return StrengthSet(id: id, exercise: exercise, weightKg: weightKg, reps: reps)
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
            cadenceSPM: data["cadenceSPM"] as? Int,
            wod: data["wod"] as? String,
            sets: (data["sets"] as? [[String: Any]] ?? []).compactMap(setFromFirestore),
            completed: data["completed"] as? Bool ?? false,
            notes: data["notes"] as? String ?? "",
            isPriority: data["isPriority"] as? Bool ?? false,
            targetRaceID: data["targetRaceID"] as? String,
            rpe: data["rpe"] as? Int
        )
    }
}
