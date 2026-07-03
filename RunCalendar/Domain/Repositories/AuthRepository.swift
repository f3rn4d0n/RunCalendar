import Foundation

/// Credenciales obtenidas de Sign in with Apple para pasar a la capa de datos.
struct AppleCredential: Sendable {
    let idTokenString: String
    let rawNonce: String
    let fullName: String?
}

/// Tokens obtenidos del flujo de Google Sign-In para pasar a la capa de datos.
struct GoogleCredential: Sendable {
    let idToken: String
    let accessToken: String
}

/// Contrato de autenticación. La capa Data lo implementa con Firebase Auth.
protocol AuthRepository: Sendable {
    /// Usuario actual si hay sesión activa.
    var currentUser: AppUser? { get }

    /// Stream del estado de autenticación (emite al cambiar la sesión).
    func authStateStream() -> AsyncStream<AppUser?>

    func signIn(email: String, password: String) async throws -> AppUser
    func signUp(email: String, password: String) async throws -> AppUser
    func signInWithApple(_ credential: AppleCredential) async throws -> AppUser
    func signInWithGoogle(_ credential: GoogleCredential) async throws -> AppUser
    func signOut() throws
}
