import Foundation
import FirebaseFirestore

/// Implementación de `FeedbackRepository` sobre Cloud Firestore.
/// Colección **raíz** `feedback/{autoID}` (no bajo `users/`) para que todos los
/// comentarios se lean juntos. Necesita su propia regla en la consola:
/// `match /feedback/{id} { allow create: if request.auth != null; allow read, update, delete: if false; }`
final class FirestoreFeedbackRepository: FeedbackRepository, @unchecked Sendable {

    private let db = Firestore.firestore()

    func submit(_ feedback: Feedback, userID: String) async throws {
        try await db.collection("feedback").document()
            .setData(FeedbackDTO.toFirestore(feedback, userID: userID))
    }
}
