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
            Log.training.info("Suscribiendo a users/\(userID, privacy: .public)/trainings")
            let listener = collection(userID)
                .order(by: "date", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        Log.training.error("snapshot trainings: \(error.localizedDescription, privacy: .public)")
                        continuation.yield([])
                        return
                    }
                    guard let documents = snapshot?.documents else {
                        Log.training.notice("Snapshot de trainings sin documentos")
                        continuation.yield([])
                        return
                    }
                    let sessions = documents.compactMap { doc -> TrainingSession? in
                        guard let session = TrainingDTO.toDomain(id: doc.documentID, data: doc.data()) else {
                            Log.training.warning("No se pudo mapear el doc \(doc.documentID, privacy: .public)")
                            return nil
                        }
                        return session
                    }
                    Log.training.info("trainings: \(documents.count) recibidos, \(sessions.count) mapeados")
                    continuation.yield(sessions)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    func add(_ session: TrainingSession, userID: String) async throws {
        Log.training.info("add training \(session.id, privacy: .public) uid=\(userID, privacy: .public)")
        try await collection(userID).document(session.id).setData(TrainingDTO.toFirestore(session))
    }

    func update(_ session: TrainingSession, userID: String) async throws {
        Log.training.info("Actualizando training \(session.id, privacy: .public)")
        try await collection(userID).document(session.id)
            .setData(TrainingDTO.toFirestore(session), merge: true)
    }

    func delete(sessionID: String, userID: String) async throws {
        Log.training.info("Eliminando training \(sessionID, privacy: .public)")
        try await collection(userID).document(sessionID).delete()
    }
}
