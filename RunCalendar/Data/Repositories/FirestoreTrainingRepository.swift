import Foundation
import FirebaseFirestore

/// Implementación de `TrainingRepository` sobre Cloud Firestore.
/// Estructura: `users/{uid}/trainings/{trainingId}`.
final class FirestoreTrainingRepository: TrainingRepository, @unchecked Sendable {

    private let db = Firestore.firestore()

    private func collection(_ userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("trainings")
    }

    func trainingsStream(userID: String) -> AsyncStream<[TrainingSession]> {
        AsyncStream { continuation in
            let listener = collection(userID)
                .order(by: "date")
                .addSnapshotListener { snapshot, _ in
                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }
                    let sessions = documents.compactMap {
                        TrainingDTO.toDomain(id: $0.documentID, data: $0.data())
                    }
                    continuation.yield(sessions)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    func add(_ session: TrainingSession, userID: String) async throws {
        try await collection(userID).document(session.id).setData(TrainingDTO.toFirestore(session))
    }

    func update(_ session: TrainingSession, userID: String) async throws {
        try await collection(userID).document(session.id)
            .setData(TrainingDTO.toFirestore(session), merge: true)
    }

    func delete(sessionID: String, userID: String) async throws {
        try await collection(userID).document(sessionID).delete()
    }
}
