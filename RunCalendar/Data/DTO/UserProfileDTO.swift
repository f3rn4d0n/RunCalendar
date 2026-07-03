import Foundation
import FirebaseFirestore

/// Mapeo entre `UserProfile` (dominio) y el documento `users/{uid}` de Firestore.
enum UserProfileDTO {

    static func toFirestore(_ profile: UserProfile) -> [String: Any] {
        var dict: [String: Any] = [
            "displayName": profile.displayName,
            "phone": profile.phone,
            "emergencyContactName": profile.emergencyContactName,
            "emergencyContactPhone": profile.emergencyContactPhone
        ]
        dict["birthday"] = profile.birthday.map { Timestamp(date: $0) }
        return dict
    }

    static func toDomain(data: [String: Any]) -> UserProfile {
        UserProfile(
            displayName: data["displayName"] as? String ?? "",
            phone: data["phone"] as? String ?? "",
            emergencyContactName: data["emergencyContactName"] as? String ?? "",
            emergencyContactPhone: data["emergencyContactPhone"] as? String ?? "",
            birthday: (data["birthday"] as? Timestamp)?.dateValue()
        )
    }
}
