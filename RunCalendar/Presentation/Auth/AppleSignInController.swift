import AuthenticationServices
import UIKit

/// Ejecuta el flujo de Sign in with Apple desde un botón personalizado (icon-only).
/// Cumple los lineamientos de Apple usando el flujo real de `ASAuthorizationController`.
final class AppleSignInController: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private var completion: ((Result<ASAuthorization, Error>) -> Void)?
    private var selfRetain: AppleSignInController?

    /// Inicia el flujo. `configure` prepara la petición (scopes + nonce).
    func start(
        configure: (ASAuthorizationAppleIDRequest) -> Void,
        completion: @escaping (Result<ASAuthorization, Error>) -> Void
    ) {
        self.completion = completion
        self.selfRetain = self // se mantiene vivo durante el flujo asíncrono

        let request = ASAuthorizationAppleIDProvider().createRequest()
        configure(request)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        finish(.success(authorization))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finish(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private func finish(_ result: Result<ASAuthorization, Error>) {
        completion?(result)
        completion = nil
        selfRetain = nil
    }
}
