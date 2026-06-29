import Foundation
import FirebaseAuth

/// Implementación de `AuthRepository` sobre Firebase Auth.
final class FirebaseAuthRepository: AuthRepository, @unchecked Sendable {

    private let auth = Auth.auth()

    var currentUser: AppUser? {
        auth.currentUser.map(Self.mapUser)
    }

    func authStateStream() -> AsyncStream<AppUser?> {
        AsyncStream { continuation in
            let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user.map(Self.mapUser))
            }
            continuation.onTermination = { @Sendable _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            return Self.mapUser(result.user)
        } catch {
            throw Self.mapError(error)
        }
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            return Self.mapUser(result.user)
        } catch {
            throw Self.mapError(error)
        }
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> AppUser {
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: credential.idTokenString,
            rawNonce: credential.rawNonce,
            fullName: nil
        )
        do {
            let result = try await auth.signIn(with: firebaseCredential)
            // Persistir el nombre la primera vez (Apple solo lo entrega una vez).
            if let name = credential.fullName, result.user.displayName == nil {
                let change = result.user.createProfileChangeRequest()
                change.displayName = name
                try? await change.commitChanges()
            }
            return Self.mapUser(result.user)
        } catch {
            throw Self.mapError(error)
        }
    }

    func signOut() throws {
        try auth.signOut()
    }

    // MARK: - Mapeo

    private static func mapUser(_ user: FirebaseAuth.User) -> AppUser {
        AppUser(id: user.uid, email: user.email, displayName: user.displayName)
    }

    private static func mapError(_ error: Error) -> AppError {
        let nsError = error as NSError
        switch AuthErrorCode(rawValue: nsError.code) {
        case .wrongPassword, .invalidCredential:
            return .invalidInput("Correo o contraseña incorrectos.")
        case .emailAlreadyInUse:
            return .invalidInput("Ese correo ya está registrado.")
        case .invalidEmail:
            return .invalidInput("Correo inválido.")
        case .weakPassword:
            return .invalidInput("La contraseña es demasiado débil.")
        case .networkError:
            return .network(nsError.localizedDescription)
        default:
            return .unknown(nsError.localizedDescription)
        }
    }
}
