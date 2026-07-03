import Foundation

/// Perfil editable del usuario, almacenado en el documento `users/{uid}`.
/// Independiente de `AppUser` (que viene de Firebase Auth: id/email).
struct UserProfile: Equatable, Sendable {
    var displayName: String
    var phone: String
    var emergencyContactName: String
    var emergencyContactPhone: String
    var birthday: Date?

    init(
        displayName: String = "",
        phone: String = "",
        emergencyContactName: String = "",
        emergencyContactPhone: String = "",
        birthday: Date? = nil
    ) {
        self.displayName = displayName
        self.phone = phone
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.birthday = birthday
    }

    /// Edad en años calculada a partir del cumpleaños.
    var age: Int? {
        guard let birthday else { return nil }
        return Calendar.current.dateComponents([.year], from: birthday, to: Date()).year
    }
}
