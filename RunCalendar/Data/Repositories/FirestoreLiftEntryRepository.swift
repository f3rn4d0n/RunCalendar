import Foundation
import FirebaseFirestore

/// Implementación de `LiftEntryRepository` sobre Cloud Firestore.
/// Estructura: `users/{uid}/liftEntries/{id}`. Cae bajo el wildcard de seguridad de `users/{uid}`
/// que ya cubre toda subcolección del usuario — no hace falta una regla nueva.
final class FirestoreLiftEntryRepository: LiftEntryRepository, @unchecked Sendable {

    private let db = Firestore.firestore()

    private func collection(_ userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("liftEntries")
    }

    func entriesStream(userID: String) -> AsyncStream<[LiftEntry]> {
        AsyncStream { continuation in
            Log.training.info("Suscribiendo a users/\(userID, privacy: .public)/liftEntries")
            let listener = collection(userID)
                .order(by: "date", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        Log.training.failure("snapshot de liftEntries", error)
                        continuation.yield([])
                        return
                    }
                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }
                    let entries = documents.compactMap { doc in
                        LiftEntryDTO.toDomain(id: doc.documentID, data: doc.data())
                    }
                    continuation.yield(entries)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    func add(_ entry: LiftEntry, userID: String) async throws {
        try await collection(userID).document(entry.id).setData(LiftEntryDTO.toFirestore(entry))
    }

    func update(_ entry: LiftEntry, userID: String) async throws {
        try await collection(userID).document(entry.id)
            .setData(LiftEntryDTO.toFirestore(entry), merge: true)
    }

    func delete(entryID: String, userID: String) async throws {
        try await collection(userID).document(entryID).delete()
    }
}
