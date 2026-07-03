import Foundation

/// Contrato de persistencia del perfil del usuario. Implementado con Firestore en la capa Data.
protocol ProfileRepository: Sendable {
    /// Stream del perfil del usuario. Reacciona a cambios remotos.
    /// Emite `nil` mientras no exista un documento de perfil.
    func profileStream(userID: String) -> AsyncStream<UserProfile?>

    func save(_ profile: UserProfile, userID: String) async throws
}
