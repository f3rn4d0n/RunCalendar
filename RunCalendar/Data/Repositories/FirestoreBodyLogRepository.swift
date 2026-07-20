import Foundation
import FirebaseFirestore

/// Implementación de `BodyLogRepository` sobre Cloud Firestore.
/// Un documento por día en `users/{uid}/bodyLogs/{yyyy-MM-dd}`.
final class FirestoreBodyLogRepository: BodyLogRepository, @unchecked Sendable {

    private let db = Firestore.firestore()

    private func collection(_ userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("bodyLogs")
    }

    func save(_ log: BodyLog, userID: String) async throws {
        let id = BodyLogDTO.documentID(for: log.date)
        try await collection(userID).document(id)
            .setData(BodyLogDTO.toFirestore(log), merge: true)
    }

    func fetchRecent(days: Int, userID: String) async throws -> [BodyLog] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshot = try await collection(userID)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .order(by: "date", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { BodyLogDTO.toDomain($0.data()) }
    }
}
