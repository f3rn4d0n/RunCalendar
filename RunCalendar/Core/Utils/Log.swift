import Foundation
import OSLog
import FirebaseAnalytics
import FirebaseCrashlytics

/// Punto único de logging de la app, basado en `os.Logger` (unified logging de Apple).
///
/// Ventajas sobre `print`:
/// - Se ve en la consola de Xcode y también en **Console.app** (filtra por subsistema/categoría).
/// - Tiene niveles (`debug`, `info`, `notice`, `error`, `fault`) y bajo impacto en rendimiento.
/// - Permite controlar la privacidad de cada valor interpolado.
///
/// Uso: `Log.races.info("Recibidos \(count, privacy: .public) docs")`
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "RunCalendar"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let races = Logger(subsystem: subsystem, category: "Races")
    static let training = Logger(subsystem: subsystem, category: "Training")
    static let profile = Logger(subsystem: subsystem, category: "Profile")
    static let health = Logger(subsystem: subsystem, category: "Health")

    /// Apaga en Debug lo que se manda fuera: el panel es para lo que pasa en dispositivos de
    /// verdad, no para los crashes del simulador ni para los eventos que dispara uno mismo
    /// probando la pantalla veinte veces seguidas. Llamar después de `FirebaseApp.configure()`.
    ///
    /// Los eventos de uso siguen escribiéndose al log del sistema en Debug (ver `Usage`), así que
    /// se puede comprobar que se disparan sin ensuciar los datos.
    static func configureObservability() {
        #if DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        Analytics.setAnalyticsCollectionEnabled(false)
        #endif
    }
}

extension Logger {
    /// Registra un fallo **no fatal**: al log del sistema (visible en Console.app) y a Crashlytics.
    ///
    /// Es el reemplazo de `Log.x.error("contexto: \(error...)")` en los `catch`. La app siguió
    /// funcionando, pero el atleta perdió algo en silencio —no se importó de Salud, no cargó la
    /// ruta, no se guardó el peso— y sin esto solo se sabría con el Mac conectado.
    ///
    /// `context` es texto nuestro (`"route: al leer la traza"`), nunca datos del usuario: viaja a
    /// un servicio externo. `localizedDescription` puede traer detalle del sistema, y por eso el
    /// mensaje se marca `.public` a conciencia — son errores de framework, no PII.
    func failure(_ context: String, _ error: Error) {
        self.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.log(context)
        crashlytics.record(error: error)
    }
}
