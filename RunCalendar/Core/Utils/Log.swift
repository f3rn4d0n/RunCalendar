import Foundation
import OSLog

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
}
