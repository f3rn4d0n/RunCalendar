import Foundation
import FirebaseFirestore

/// Implementación de `RaceRepository` sobre Cloud Firestore.
/// Estructura: `users/{uid}/races/{raceId}`.
final class FirestoreRaceRepository: RaceRepository, @unchecked Sendable {

    private let db = Firestore.firestore()

    private func collection(_ userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("races")
    }

    func racesStream(userID: String) -> AsyncStream<[Race]> {
        AsyncStream { continuation in
            let listener = collection(userID)
                .order(by: "date")
                .addSnapshotListener { snapshot, _ in
                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }
                    let races = documents.compactMap { RaceDTO.toDomain(id: $0.documentID, data: $0.data()) }
                    continuation.yield(races)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    func add(_ race: Race, userID: String) async throws {
        try await collection(userID).document(race.id).setData(RaceDTO.toFirestore(race))
    }

    func update(_ race: Race, userID: String) async throws {
        try await collection(userID).document(race.id).setData(RaceDTO.toFirestore(race), merge: true)
    }

    func delete(raceID: String, userID: String) async throws {
        try await collection(userID).document(raceID).delete()
    }
}
