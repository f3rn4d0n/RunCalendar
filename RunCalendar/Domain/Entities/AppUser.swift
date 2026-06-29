import Foundation

/// Usuario autenticado. Entidad de dominio independiente de Firebase.
struct AppUser: Identifiable, Equatable, Sendable {
    let id: String        // uid de Firebase Auth
    let email: String?
    let displayName: String?

    init(id: String, email: String? = nil, displayName: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
    }
}
