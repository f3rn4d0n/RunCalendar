import SwiftUI
import StoreKit

/// Pide la valoración nativa de la App Store **una sola vez**, cuando el atleta
/// lleva al menos una semana con la app. Si ya dio su opinión —mandó un
/// comentario, o ya se le pidió valorar— no se vuelve a preguntar.
///
/// Apple ya limita `requestReview` a 3 veces al año y no muestra nada si el
/// usuario ya valoró; esto solo decide *cuándo pedirlo la primera vez*.
///
/// ponytail: "una semana" es tiempo de calendario desde el primer arranque, no
/// días de uso real. Si hiciera falta afinar, contar aperturas distintas aquí.
@MainActor
enum AppReviewPrompt {
    private static let firstLaunchKey = "review.firstLaunchAt"
    private static let askedKey = "review.asked"
    private static let minDays = 7

    /// Registra el primer arranque. Idempotente; llamar al iniciar la app.
    static func recordFirstLaunch() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: firstLaunchKey)
        }
    }

    /// El atleta ya opinó (mandó comentario o ya se le pidió valorar): no volver
    /// a interrumpirlo con el prompt semanal.
    static func markAsked() {
        UserDefaults.standard.set(true, forKey: askedKey)
    }

    /// Si toca, dispara el prompt nativo y lo marca como hecho.
    static func askIfDue(_ requestReview: RequestReviewAction) {
        let defaults = UserDefaults.standard
        let firstLaunch = (defaults.object(forKey: firstLaunchKey) as? Double)
            .map { Date(timeIntervalSince1970: $0) }
        guard isDue(now: Date(), firstLaunch: firstLaunch,
                    alreadyAsked: defaults.bool(forKey: askedKey)) else { return }
        requestReview()
        markAsked()
    }

    /// Parte pura y comprobable de `askIfDue`.
    static func isDue(now: Date, firstLaunch: Date?, alreadyAsked: Bool) -> Bool {
        guard !alreadyAsked, let firstLaunch else { return false }
        return now.timeIntervalSince(firstLaunch) >= Double(minDays) * 86_400
    }
}
