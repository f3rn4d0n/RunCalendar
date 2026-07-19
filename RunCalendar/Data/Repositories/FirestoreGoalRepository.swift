import Foundation
import FirebaseFirestore

/// Implementación de `GoalRepository` sobre Cloud Firestore.
/// Estructura: `users/{uid}/goals/{goalId}`.
final class FirestoreGoalRepository: GoalRepository, @unchecked Sendable {

    private let db = Firestore.firestore()

    private func collection(_ userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("goals")
    }

    func goalsStream(userID: String) -> AsyncStream<[Goal]> {
        AsyncStream { continuation in
            let listener = collection(userID)
                .order(by: "createdAt")
                .addSnapshotListener { snapshot, error in
                    if let error {
                        Log.races.error("Error en snapshot de goals: \(error.localizedDescription, privacy: .public)")
                        continuation.yield([])
                        return
                    }
                    let goals = (snapshot?.documents ?? []).compactMap {
                        GoalDTO.toDomain(id: $0.documentID, data: $0.data())
                    }
                    continuation.yield(goals)
                }
            continuation.onTermination = { @Sendable _ in listener.remove() }
        }
    }

    func add(_ goal: Goal, userID: String) async throws {
        try await collection(userID).document(goal.id).setData(GoalDTO.toFirestore(goal))
    }

    func update(_ goal: Goal, userID: String) async throws {
        try await collection(userID).document(goal.id).setData(GoalDTO.toFirestore(goal), merge: true)
    }

    func delete(goalID: String, userID: String) async throws {
        try await collection(userID).document(goalID).delete()
    }
}
