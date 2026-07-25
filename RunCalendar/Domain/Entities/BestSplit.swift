import Foundation

/// El tramo continuo más rápido de una distancia dentro de un entrenamiento de Salud.
/// Es el mismo criterio que usa la app Fitness del Watch para sus récords: tu mejor 5K
/// puede vivir dentro de una corrida de 10 km, no solo en una corrida que midió 5 km.
struct BestSplit: Equatable, Sendable, Identifiable {
    let workoutID: String
    /// Distancia objetivo del tramo en km (5, 10, 21.0975, …).
    let distanceKm: Double
    let seconds: Int
    /// Inicio del entrenamiento que lo contiene (sirve para casarlo con la sesión importada).
    let date: Date
    /// Distancia total de ese entrenamiento, para poder decir "dentro de tu corrida de 9.4 km".
    let workoutKm: Double

    var id: String { "\(workoutID)-\(distanceKm)" }
}

extension BestSplit {
    /// Un punto de la curva de distancia acumulada de un entrenamiento: metros recorridos
    /// a los `seconds` segundos de haber empezado. Creciente en ambas coordenadas.
    typealias CurvePoint = (seconds: Double, meters: Double)

    /// Segundos del tramo continuo más rápido que cubre `meters`, con dos punteros sobre la curva.
    /// `nil` si el entrenamiento nunca llegó a esa distancia.
    ///
    /// ponytail: los inicios de ventana caen en muestras (Salud las escribe ~cada segundo) y solo
    /// se interpola el final; barrer el continuo no movería el récord ni un segundo.
    /// El tiempo es de reloj: si pausaste dentro del tramo, la pausa cuenta.
    static func fastestWindow(_ curve: [CurvePoint], meters: Double) -> Int? {
        guard let total = curve.last?.meters, total >= meters, meters > 0 else { return nil }
        var best = Double.infinity
        var end = 0
        for start in curve.indices {
            if end < start { end = start }
            while end < curve.count && curve[end].meters - curve[start].meters < meters { end += 1 }
            guard end < curve.count else { break }
            // Instante exacto en que se cumplen los `meters`, interpolado entre los dos puntos
            // que lo cruzan (si no, el tramo se mediría siempre de más).
            let previous = curve[end - 1], crossed = curve[end]
            let span = crossed.meters - previous.meters
            let missing = curve[start].meters + meters - previous.meters
            let elapsed = (crossed.seconds - previous.seconds) * (span > 0 ? missing / span : 0)
            best = min(best, previous.seconds + elapsed - curve[start].seconds)
        }
        return best.isFinite ? Int(best.rounded()) : nil
    }
}
