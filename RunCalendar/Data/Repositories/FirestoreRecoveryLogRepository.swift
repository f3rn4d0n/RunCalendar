import Foundation
import FirebaseFirestore

/// Implementación de `RecoveryLogRepository` sobre Cloud Firestore.
/// Un documento por día en `users/{uid}/recoveryLogs/{yyyy-MM-dd}`.
final class FirestoreRecoveryLogRepository: RecoveryLogRepository, @unchecked Sendable {

    private let db = Firestore.firestore()

    private func collection(_ userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("recoveryLogs")
    }

    func save(_ checkIn: RecoveryCheckIn, userID: String) async throws {
        let id = RecoveryCheckInDTO.documentID(for: checkIn.date)
        try await collection(userID).document(id)
            .setData(RecoveryCheckInDTO.toFirestore(checkIn), merge: true)
    }

    func fetchRecent(days: Int, userID: String) async throws -> [RecoveryCheckIn] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let snapshot = try await collection(userID)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .order(by: "date")
            .getDocuments()
        return snapshot.documents.compactMap { RecoveryCheckInDTO.toDomain($0.data()) }
    }
}
