import Foundation
import Observation
import AuthenticationServices

/// Estado de la sesión a nivel de toda la app.
@MainActor
@Observable
final class AuthViewModel {

    enum SessionState: Equatable {
        case loading
        case signedOut
        case signedIn(AppUser)
    }

    private(set) var state: SessionState = .loading
    var errorMessage: String?
    var isProcessing = false

    // Nonce vigente para el flujo de Sign in with Apple.
    private var currentNonce: String?

    private let observeAuthState: ObserveAuthStateUseCase
    private let signIn: SignInWithEmailUseCase
    private let signUp: SignUpUseCase
    private let signInWithApple: SignInWithAppleUseCase
    private let signOut: SignOutUseCase

    init(
        observeAuthState: ObserveAuthStateUseCase,
        signIn: SignInWithEmailUseCase,
        signUp: SignUpUseCase,
        signInWithApple: SignInWithAppleUseCase,
        signOut: SignOutUseCase
    ) {
        self.observeAuthState = observeAuthState
        self.signIn = signIn
        self.signUp = signUp
        self.signInWithApple = signInWithApple
        self.signOut = signOut
    }

    /// Escucha cambios de sesión (Firebase) durante toda la vida de la app.
    func start() async {
        for await user in observeAuthState() {
            if let user {
                let email = user.email ?? "nil"
                Log.auth.info("Sesión activa uid=\(user.id, privacy: .public) email=\(email, privacy: .public)")
            } else {
                Log.auth.info("Sin sesión activa")
            }
            state = user.map(SessionState.signedIn) ?? .signedOut
        }
    }

    func signInWithEmail(email: String, password: String) async {
        await run { _ = try await self.signIn(email: email, password: password) }
    }

    func register(email: String, password: String) async {
        await run { _ = try await self.signUp(email: email, password: password) }
    }

    func logOut() {
        do { try signOut() } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Sign in with Apple

    /// Configura la petición de Apple con un nonce nuevo.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = NonceGenerator.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(nonce)
    }

    /// Procesa el resultado del botón de Apple.
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = credential.identityToken,
                let tokenString = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "No se pudo completar el inicio con Apple."
                return
            }
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let appleCredential = AppleCredential(
                idTokenString: tokenString,
                rawNonce: nonce,
                fullName: fullName.isEmpty ? nil : fullName
            )
            await run { _ = try await self.signInWithApple(appleCredential) }
        }
    }

    // MARK: - Helper

    private func run(_ operation: @escaping () async throws -> Void) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
