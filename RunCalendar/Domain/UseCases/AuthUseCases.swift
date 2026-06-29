import Foundation

/// Observa el estado de autenticación.
struct ObserveAuthStateUseCase: Sendable {
    private let repository: AuthRepository
    init(repository: AuthRepository) { self.repository = repository }

    var currentUser: AppUser? { repository.currentUser }
    func callAsFunction() -> AsyncStream<AppUser?> { repository.authStateStream() }
}

/// Inicio de sesión con email y contraseña.
struct SignInWithEmailUseCase: Sendable {
    private let repository: AuthRepository
    init(repository: AuthRepository) { self.repository = repository }

    func callAsFunction(email: String, password: String) async throws -> AppUser {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@") else { throw AppError.invalidInput("Correo inválido.") }
        guard password.count >= 6 else {
            throw AppError.invalidInput("La contraseña debe tener al menos 6 caracteres.")
        }
        return try await repository.signIn(email: email, password: password)
    }
}

/// Registro de un nuevo usuario con email y contraseña.
struct SignUpUseCase: Sendable {
    private let repository: AuthRepository
    init(repository: AuthRepository) { self.repository = repository }

    func callAsFunction(email: String, password: String) async throws -> AppUser {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@") else { throw AppError.invalidInput("Correo inválido.") }
        guard password.count >= 6 else {
            throw AppError.invalidInput("La contraseña debe tener al menos 6 caracteres.")
        }
        return try await repository.signUp(email: email, password: password)
    }
}

/// Inicio de sesión con Apple.
struct SignInWithAppleUseCase: Sendable {
    private let repository: AuthRepository
    init(repository: AuthRepository) { self.repository = repository }

    func callAsFunction(_ credential: AppleCredential) async throws -> AppUser {
        try await repository.signInWithApple(credential)
    }
}

/// Cierre de sesión.
struct SignOutUseCase: Sendable {
    private let repository: AuthRepository
    init(repository: AuthRepository) { self.repository = repository }

    func callAsFunction() throws { try repository.signOut() }
}
