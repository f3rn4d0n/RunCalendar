import Foundation
import FirebaseFirestore

/// `WeekPlanRepository` sobre Cloud Firestore. Un documento por semana en
/// `users/{uid}/weekPlans/{yyyy-MM-dd}`, con el lunes como id.
///
/// El plan se guarda **como JSON en un campo**, no desplegado en campos de Firestore. Es un árbol
/// con enumeraciones y opcionales que solo se lee entero, y mapearlo campo a campo costaría un DTO
/// grande que hay que mantener en paralelo a las entidades. Lo único que se consulta —la fecha— sí
/// va en su propio campo, que es lo que permite ordenar y filtrar.
final class FirestoreWeekPlanRepository: WeekPlanRepository, @unchecked Sendable {

    private let db = Firestore.firestore()

    private func collection(_ userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("weekPlans")
    }

    private static let idFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    func save(_ week: FrozenWeek, userID: String) async throws {
        let json = try JSONEncoder().encode(week.plan)
        try await collection(userID).document(Self.idFormatter.string(from: week.weekStart))
            .setData([
                "weekStart": Timestamp(date: week.weekStart),
                "fingerprint": week.fingerprint,
                "plan": String(decoding: json, as: UTF8.self)
            ], merge: true)
    }

    func fetch(weekStart: Date, userID: String) async throws -> FrozenWeek? {
        let doc = try await collection(userID)
            .document(Self.idFormatter.string(from: weekStart)).getDocument()
        return doc.data().flatMap(Self.toDomain)
    }

    func recent(weeks: Int, userID: String) async throws -> [FrozenWeek] {
        let snapshot = try await collection(userID)
            .order(by: "weekStart", descending: true)
            .limit(to: weeks)
            .getDocuments()
        return snapshot.documents.compactMap { Self.toDomain($0.data()) }
    }

    private static func toDomain(_ data: [String: Any]) -> FrozenWeek? {
        guard let weekStart = (data["weekStart"] as? Timestamp)?.dateValue(),
              let fingerprint = data["fingerprint"] as? String,
              let json = data["plan"] as? String,
              let plan = try? JSONDecoder().decode(TrainingPlan.self, from: Data(json.utf8))
        else { return nil }
        return FrozenWeek(weekStart: weekStart, fingerprint: fingerprint, plan: plan)
    }
}
