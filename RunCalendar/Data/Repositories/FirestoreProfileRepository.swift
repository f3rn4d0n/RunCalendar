import Foundation
import FirebaseFirestore

/// Implementación de `ProfileRepository` sobre Cloud Firestore.
/// El perfil se guarda en el propio documento `users/{uid}`.
final class FirestoreProfileRepository: ProfileRepository, @unchecked Sendable {

    private let db = Firestore.firestore()

    private func document(_ userID: String) -> DocumentReference {
        db.collection("users").document(userID)
    }

    func profileStream(userID: String) -> AsyncStream<UserProfile?> {
        AsyncStream { continuation in
            Log.profile.info("Suscribiendo a users/\(userID, privacy: .public)")
            let listener = document(userID).addSnapshotListener { snapshot, error in
                if let error {
                    Log.profile.error("snapshot perfil: \(error.localizedDescription, privacy: .public)")
                    continuation.yield(nil)
                    return
                }
                guard let data = snapshot?.data() else {
                    Log.profile.notice("Perfil aún no existe")
                    continuation.yield(nil)
                    return
                }
                continuation.yield(UserProfileDTO.toDomain(data: data))
            }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    func save(_ profile: UserProfile, userID: String) async throws {
        Log.profile.info("Guardando perfil de uid=\(userID, privacy: .public)")
        // merge:true para no afectar otros campos ni las subcolecciones del documento.
        try await document(userID).setData(UserProfileDTO.toFirestore(profile), merge: true)
    }
}
