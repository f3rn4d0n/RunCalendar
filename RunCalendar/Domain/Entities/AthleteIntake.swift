import Foundation

/// Qué busca el atleta de su entrenamiento. **Cambia la estructura de la semana**, no solo el tono
/// de los textos.
///
/// El motor asumía siempre `performance`: series + tempo + tirada larga para todo el mundo. A quien
/// solo quiere terminar su primer 21K eso le mete intensidad que no necesita y le roba el volumen
/// que sí, y a quien solo quiere mantenerse le prescribe un bloque de calidad que nunca pidió.
enum TrainingIntent: String, CaseIterable, Identifiable, Sendable {
    /// Bajar una marca. La semana completa: calidad, umbral y tirada larga.
    case performance = "Mejorar mi marca"
    /// Completar una distancia. Manda el volumen y la tirada larga; una sola sesión de calidad.
    case finish = "Terminar la distancia"
    /// Sostener la forma. **Menos volumen, misma intensidad** — que es al revés de lo que parece.
    case maintain = "Mantener mi forma"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var hint: String {
        switch self {
        case .performance: return "Tienes un tiempo en la cabeza y quieres bajarlo."
        case .finish:      return "Quieres cruzar la meta, el reloj da igual."
        case .maintain:    return "No hay carrera a la vista; quieres no perder lo ganado."
        }
    }
}

/// Lo que el atleta **declara** y ninguna medición puede ver.
///
/// La regla que decide qué entra aquí y qué no: los **hechos del pasado** (cuánto corriste, si hubo
/// un parón, tu tirada más larga) salen de Salud y no se preguntan; la **intención y la capacidad**
/// (cuántos días puedes, qué quieres, dónde puedes entrenar) no están en ningún dato y solo pueden
/// declararse. Ver *Lo que el motor no puede saber* en `docs/motor-de-entrenamiento.md`.
///
/// ponytail: en `UserDefaults` como `PlanConfig`, por la misma razón y con la misma consecuencia
/// (no sincroniza entre dispositivos). Se mueve a Firestore cuando exista el bloque persistido, que
/// es donde esto acaba viviendo.
struct AthleteIntake: Equatable, Sendable {
    var intent: TrainingIntent
    /// Si el atleta tiene dónde hacer repeticiones en cuesta. Sin esto, el motor las propone a
    /// cualquiera — y quien vive en una ciudad plana se queda con una sesión que no puede hacer.
    var hasHills: Bool
    /// Km semanales declarados, **solo** para quien no tiene historial en Salud. Con historial esto
    /// se observa y preguntarlo sería pedir un dato que ya tenemos.
    var declaredWeeklyKm: Double?

    static let `default` = AthleteIntake(intent: .performance, hasHills: true,
                                         declaredWeeklyKm: nil)
}
