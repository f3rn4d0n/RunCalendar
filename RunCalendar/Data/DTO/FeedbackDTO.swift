import Foundation
import FirebaseFirestore

/// Mapeo de `Feedback` a su documento de Firestore.
/// Solo escritura: el equipo lee estos documentos desde la consola, no la app.
enum FeedbackDTO {

    static func toFirestore(_ feedback: Feedback, userID: String) -> [String: Any] {
        [
            "userID": userID,
            "text": feedback.text,
            "rating": feedback.rating,
            "createdAt": Timestamp(date: feedback.createdAt),
            "appVersion": feedback.appVersion,
            "systemVersion": feedback.systemVersion
        ]
    }
}
