import Foundation
import FirebaseAnalytics

/// Los cinco eventos de uso de la app. **Todo lo que la app manda a un servicio externo sobre lo
/// que hace el atleta sale de este archivo**, y de ningún otro sitio: así la revisión de privacidad
/// es leer una pantalla, no auditar el proyecto.
///
/// No es analítica de producto. No hay embudos, ni vistas de pantalla, ni identificadores de
/// usuario: es responder *¿la app se usa o solo se abre?* antes de tener una beta, que es cuando
/// esa respuesta todavía se puede conseguir.
///
/// **Regla dura: aquí no viaja ningún dato del atleta.** Solo conteos y valores de enumeraciones
/// nuestras, que son un conjunto cerrado y conocido. Nada de nombres de carreras, notas,
/// kilometrajes, pesos, fechas ni ids. Si un evento nuevo necesita algo que no sea un número o un
/// `case`, no es un evento: es telemetría de producto y eso está fuera de alcance.
///
/// Se apaga en Debug junto con Crashlytics, en `Log.configureObservability()`.
///
/// ponytail: cinco eventos y ninguna abstracción. Si algún día hay que mandarlos a dos destinos,
/// ahí se mete un protocolo — hoy sería una interfaz con una sola implementación.
enum Usage {

    /// Se importaron carreras de Salud. El número es lo que importa: distingue "el import funciona"
    /// de "el import corre y siempre trae cero", que desde fuera se ven igual.
    static func healthImported(count: Int) {
        log("health_imported", ["count": count])
    }

    /// El atleta configuró su plan. Sin esto no hay forma de saber si alguien pasa de la pantalla
    /// de metas, que es el paso donde la app deja de ser un registro y se vuelve un coach.
    static func planConfigured(daysPerWeek: Int, fromSuggestion: Bool) {
        log("plan_configured", ["days_per_week": daysPerWeek, "from_suggestion": fromSuggestion])
    }

    /// Se marcó una sesión como completada.
    static func sessionCompleted(type: TrainingType) {
        log("session_completed", ["training_type": key(of: type)])
    }

    /// Se guardó el review dominical. Es el hábito más frágil de la app: pide sentarse un domingo
    /// a capturar peso, cintura, energía y hambre.
    static func weeklyReviewSaved() {
        log("weekly_review_saved")
    }

    /// Se mandó un entrenamiento estructurado al Apple Watch.
    static func workoutSentToWatch(kind: PlannedWorkoutKind) {
        log("workout_sent_to_watch", ["workout_kind": key(of: kind)])
    }

    // MARK: - Interno

    /// Identificador estable en inglés para un `case`. **No** se manda el `rawValue`: esos son los
    /// textos que ve el usuario ("Tirada larga", "Carrera") y cambiarlos por redacción rompería la
    /// serie histórica del panel sin que nadie lo relacione.
    private static func key(of type: TrainingType) -> String {
        switch type {
        case .crossfit: return "crossfit"
        case .running:  return "running"
        case .walking:  return "walking"
        case .hiking:   return "hiking"
        case .other:    return "other"
        }
    }

    private static func key(of kind: PlannedWorkoutKind) -> String {
        switch kind {
        case .longRun:   return "long_run"
        case .tempo:     return "tempo"
        case .intervals: return "intervals"
        case .easy:      return "easy"
        case .race:      return "race"
        }
    }

    /// Un solo camino de salida, para que la regla de "aquí no viaja nada del atleta" se pueda
    /// verificar mirando quién llama a esto. En Debug la recolección está apagada, pero se escribe
    /// al log del sistema igual: es la única forma de comprobar que el evento se dispara cuando
    /// debe sin esperar 24 h al panel de Firebase.
    private static func log(_ name: String, _ parameters: [String: Any] = [:]) {
        Log.app.debug("evento: \(name, privacy: .public) \(parameters.description, privacy: .public)")
        Analytics.logEvent(name, parameters: parameters.isEmpty ? nil : parameters)
    }
}
