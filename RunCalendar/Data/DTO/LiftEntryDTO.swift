import Foundation
import FirebaseFirestore

/// Mapeo entre `LiftEntry` (dominio) y el documento de Firestore.
enum LiftEntryDTO {

    static func toFirestore(_ entry: LiftEntry) -> [String: Any] {
        [
            "exercise": entry.exercise.rawValue,
            "weightKg": entry.weightKg,
            "reps": entry.reps,
            "date": Timestamp(date: entry.date)
        ]
    }

    static func toDomain(id: String, data: [String: Any]) -> LiftEntry? {
        guard
            let exerciseRaw = data["exercise"] as? String,
            let exercise = StrengthExercise(rawValue: exerciseRaw),
            let timestamp = data["date"] as? Timestamp
        else { return nil }

        // Como NSNumber: un peso/reps escrito a mano en la consola de Firebase (p. ej. "100")
        // vuelve como Int, y `as? Double` fallaría en silencio.
        let weightKg = (data["weightKg"] as? NSNumber)?.doubleValue ?? 0
        let reps = (data["reps"] as? NSNumber)?.intValue ?? 0

        return LiftEntry(id: id, exercise: exercise, weightKg: weightKg, reps: reps,
                         date: timestamp.dateValue())
    }
}
