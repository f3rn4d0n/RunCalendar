import Foundation
import UIKit
import FirebaseCore
import GoogleSignIn

/// Ejecuta el flujo interactivo de Google Sign-In y devuelve los tokens
/// para que la capa de dominio los intercambie por una sesión de Firebase.
@MainActor
enum GoogleSignInService {

    /// Presenta el flujo de Google y devuelve las credenciales (idToken + accessToken).
    static func signIn() async throws -> GoogleCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AppError.unknown("Falta el CLIENT_ID de Google en GoogleService-Info.plist.")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = rootViewController() else {
            throw AppError.unknown("No se encontró la ventana para presentar el inicio con Google.")
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AppError.unknown("Google no devolvió el token de identidad.")
            }
            return GoogleCredential(idToken: idToken, accessToken: result.user.accessToken.tokenString)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.unknown(error.localizedDescription)
        }
    }

    /// View controller visible más arriba, para presentar el flujo de Google.
    private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
