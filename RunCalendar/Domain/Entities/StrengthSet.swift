import Foundation

/// Cómo se rankea el récord de un ejercicio y qué significa `StrengthSet.weightKg` en él.
enum LoadStyle: Sendable {
    /// La barra/mancuerna es la carga completa. `weightKg` es el peso total movido.
    case external
    /// El cuerpo es la carga. `weightKg` es el lastre **añadido** (0 = sin lastre); el récord se
    /// mide por repeticiones, no por un 1RM que exigiría saber el peso corporal del atleta.
    case bodyweight
}

/// Catálogo cerrado de levantamientos. Ejercicios que no estén aquí siguen cabiendo en `wod`/notas,
/// como hoy — no hay caso "Otro" a propósito.
/// ponytail: 14 casos fijos; lo que falte se agrega al enum en un release, no con un `.otro` que
/// mezclaría curl de bíceps con sentadilla en el mismo récord y lo volvería sin sentido.
enum StrengthExercise: String, CaseIterable, Identifiable, Sendable {
    case sentadilla         = "Sentadilla"
    case sentadillaFrontal  = "Sentadilla frontal"
    case pesoMuerto         = "Peso muerto"
    case pesoMuertoRumano   = "Peso muerto rumano"
    case hipThrust          = "Hip thrust"
    case pressBanca         = "Press de banca"
    case pressMilitar       = "Press militar"
    case remoConBarra       = "Remo con barra"
    case cargada            = "Cargada"
    case arranque           = "Arranque"
    case envion             = "Envión"
    case thruster           = "Thruster"
    case dominada           = "Dominada"
    case fondo              = "Fondo"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var loadStyle: LoadStyle {
        switch self {
        case .dominada, .fondo: return .bodyweight
        default:                return .external
        }
    }

    /// Solo símbolos verificados en iOS 18. Repetir símbolo entre casos es correcto —no hay un SF
    /// Symbol por levantamiento— e inventar nombres que no existen no lo es.
    var systemImage: String {
        switch self {
        case .sentadilla, .sentadillaFrontal, .pesoMuerto, .pesoMuertoRumano, .hipThrust,
             .pressBanca, .pressMilitar, .remoConBarra:
            return "figure.strengthtraining.traditional"
        case .cargada, .arranque, .envion, .thruster, .dominada, .fondo:
            return "figure.strengthtraining.functional"
        }
    }
}

/// Una serie: ejercicio, carga y repeticiones. Vive embebida en `TrainingSession.sets` —la sesión
/// de gimnasio ya existe como `.crossfit`, ya se importa de Salud y ya cuenta para la carga; una
/// colección aparte duplicaría la sesión y partiría en dos la carga del mismo día.
struct StrengthSet: Identifiable, Equatable, Sendable {
    let id: String
    var exercise: StrengthExercise
    /// Peso total (carga externa) o lastre añadido (peso corporal, 0 = sin lastre). Nunca libras.
    var weightKg: Double
    var reps: Int

    init(id: String = UUID().uuidString, exercise: StrengthExercise, weightKg: Double, reps: Int) {
        self.id = id
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
    }

    /// El "distanceKm" de una serie: cuánto se movió en total.
    var volumeKg: Double { weightKg * Double(reps) }

    /// 1RM estimado (fórmula de Epley), o `nil` si el ejercicio es de peso corporal —estimarlo ahí
    /// exigiría el peso corporal del atleta, y eso sería inventar un dato que no se tiene.
    ///
    /// ponytail: Epley (`peso × (1 + reps/30)`), sin calibrar contra nadie. Elegida sobre Brzycki
    /// porque es lineal, no se rompe cerca de 30 reps, y es la que usan Strong/Hevy —la que el
    /// atleta ya vio en otra app.
    var estimatedOneRM: Double? {
        guard exercise.loadStyle == .external, weightKg > 0, reps > 0 else { return nil }
        // Con una sola rep, Epley da 1.033× el peso: inventaría kilos que nadie levantó.
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }
}
