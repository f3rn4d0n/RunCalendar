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
            Log.races.info("Suscribiendo a users/\(userID, privacy: .public)/races")
            let listener = collection(userID)
                .order(by: "date")
                .addSnapshotListener { snapshot, error in
                    if let error {
                        Log.races.error("Error en snapshot de races: \(error.localizedDescription, privacy: .public)")
                        continuation.yield([])
                        return
                    }
                    guard let documents = snapshot?.documents else {
                        Log.races.notice("Snapshot de races sin documentos")
                        continuation.yield([])
                        return
                    }
                    let races = documents.compactMap { doc -> Race? in
                        guard let race = RaceDTO.toDomain(id: doc.documentID, data: doc.data()) else {
                            Log.races.warning("No se pudo mapear el doc \(doc.documentID, privacy: .public)")
                            return nil
                        }
                        return race
                    }
                    Log.races.info("races: \(documents.count) recibidos, \(races.count) mapeados")
                    continuation.yield(races)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    func add(_ race: Race, userID: String) async throws {
        Log.races.info("add race \(race.id, privacy: .public) uid=\(userID, privacy: .public)")
        try await collection(userID).document(race.id).setData(RaceDTO.toFirestore(race))
    }

    func update(_ race: Race, userID: String) async throws {
        Log.races.info("Actualizando race \(race.id, privacy: .public)")
        try await collection(userID).document(race.id).setData(RaceDTO.toFirestore(race), merge: true)
    }

    func delete(raceID: String, userID: String) async throws {
        Log.races.info("Eliminando race \(raceID, privacy: .public)")
        try await collection(userID).document(raceID).delete()
    }
}
