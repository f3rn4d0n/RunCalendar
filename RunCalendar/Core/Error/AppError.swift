import Foundation

/// Error de dominio agnóstico de la infraestructura (Firebase, red, etc.).
enum AppError: LocalizedError, Equatable {
    case notAuthenticated
    case invalidInput(String)
    case network(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Necesitas iniciar sesión para continuar."
        case .invalidInput(let message):
            return message
        case .network(let message):
            return "Error de conexión: \(message)"
        case .unknown(let message):
            return message
        }
    }
}
