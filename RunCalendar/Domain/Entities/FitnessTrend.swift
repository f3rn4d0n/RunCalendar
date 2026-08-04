import Foundation

/// Kilómetros corridos en una semana.
struct WeeklyVolume: Equatable, Sendable, Identifiable {
    let weekStart: Date
    let km: Double
    var id: Date { weekStart }
}

/// Ritmo de una corrida (para ver si mejoras con el tiempo).
struct RunPacePoint: Equatable, Sendable, Identifiable {
    let id: String   // uuid del workout
    let date: Date
    let paceSecondsPerKm: Int
    let distanceKm: Double
    /// Cadencia media (pasos por minuto), si el workout registró conteo de pasos.
    let stepsPerMinute: Int?

    var speedKmh: Double {
        paceSecondsPerKm > 0 ? 3600 / Double(paceSecondsPerKm) : 0
    }
}

/// Un punto de VO₂max en el tiempo (promedio de una semana).
struct VO2Point: Equatable, Sendable, Identifiable {
    let date: Date
    let value: Double   // ml/kg·min
    var id: Date { date }
}

/// Un punto de la línea base de HRV (promedio de una semana).
///
/// **Semanal y no diario a propósito.** El HRV de un día suelto varía con el alcohol, una mala
/// noche o un mal día en el trabajo; a esa escala es ruido y ya se muestra en *Recuperación*, que
/// es donde responde "¿puedo apretar hoy?". Promediado por semanas y mirado en meses responde otra
/// pregunta: **¿mi cuerpo se está adaptando?**
struct HRVPoint: Equatable, Sendable, Identifiable {
    let date: Date
    let milliseconds: Double
    var id: Date { date }
}

/// Hacia dónde va tu línea base de HRV en el medio plazo.
enum HRVBaselineTrend: Equatable, Sendable {
    case rising
    case stable
    case falling
    /// Menos de `HRVPoint.weeksForVerdict` semanas con dato: no se dice nada.
    case notEnough
}

extension HRVPoint {
    /// Semanas por bloque que se comparan. Hacen falta dos bloques para tener veredicto.
    static let weeksPerBlock = 4
    static var weeksForVerdict: Int { weeksPerBlock * 2 }

    /// Cambio mínimo (fracción) para llamarlo tendencia y no ruido.
    ///
    /// ponytail: el HRV varía ~5–10% de una semana a otra incluso sin cambiar nada, así que por
    /// debajo de esto no hay señal. Es un umbral **sin calibrar** contra datos reales — ver
    /// *Umbrales sin calibrar* en `docs/pendientes.md`.
    static let meaningfulChange = 0.05

    /// Compara el último bloque de semanas con el anterior.
    ///
    /// Bloques y no una recta de regresión porque el dato de Apple Salud es irregular —el reloj
    /// muestrea SDNN cuando le toca, no en una medición matinal controlada— y una pendiente sobre
    /// puntos dispares aparenta más precisión de la que hay.
    static func trend(of points: [HRVPoint]) -> HRVBaselineTrend {
        // Una sola guarda, y es ésta: con menos de dos bloques no hay con qué comparar. Había otra
        // más abajo comprobando `previous.count`, redundante — la mutación lo destapó, porque
        // quitar ésta no rompía ninguna prueba.
        guard points.count >= weeksForVerdict else { return .notEnough }
        let ordered = points.sorted { $0.date < $1.date }
        let recent = ordered.suffix(weeksPerBlock)
        let previous = ordered.dropLast(weeksPerBlock).suffix(weeksPerBlock)

        let average: ([HRVPoint]) -> Double = { block in
            block.reduce(0) { $0 + $1.milliseconds } / Double(block.count)
        }
        let before = average(Array(previous))
        guard before > 0 else { return .notEnough }
        let change = (average(Array(recent)) - before) / before

        if change > meaningfulChange { return .rising }
        if change < -meaningfulChange { return .falling }
        return .stable
    }
}

/// Tendencias de condición: volumen semanal, ritmo por corrida, VO₂max y línea base de HRV.
struct FitnessTrend: Equatable, Sendable {
    let weeklyVolume: [WeeklyVolume]   // últimas semanas, cronológico
    let pace: [RunPacePoint]           // corridas recientes, cronológico
    let vo2Max: [VO2Point]             // ~6 meses, semanal, cronológico
    let hrvBaseline: [HRVPoint]        // ~6 meses, semanal, cronológico

    init(weeklyVolume: [WeeklyVolume], pace: [RunPacePoint],
         vo2Max: [VO2Point], hrvBaseline: [HRVPoint] = []) {
        self.weeklyVolume = weeklyVolume
        self.pace = pace
        self.vo2Max = vo2Max
        self.hrvBaseline = hrvBaseline
    }
}
