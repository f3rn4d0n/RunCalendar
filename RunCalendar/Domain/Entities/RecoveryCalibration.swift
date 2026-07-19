import Foundation

/// Ajuste personal de la heurística de recuperación, aprendido de tus check-ins.
/// v2 (segmentada): además del sesgo global aprende cuánto se desvía en condiciones
/// adversas (HRV baja, sueño corto, carga alta) y corrige extra los días que aplican.
/// ponytail: modelo aditivo (global + offsets por condición), robusto con pocos datos e
/// interpretable. Una regresión continua sería el paso a v3 con muchos más registros.
struct RecoveryCalibration: Equatable, Sendable {
    /// Multiplicador sobre las horas necesarias, ya resuelto para las condiciones de hoy.
    let factor: Double
    /// Sesgo global (sentido − predicho); base del ajuste y para el resumen.
    let bias: Double
    /// Check-ins usados para calibrar.
    let sampleCount: Int
    /// Condiciones adversas de hoy que sumaron corrección (para explicar en la UI).
    let activeToday: [Condition]

    /// Condición segmentable, con su dirección "adversa" conocida.
    enum Condition: String, Sendable, CaseIterable {
        case lowHRV = "HRV baja"
        case shortSleep = "poco sueño"
        case highLoad = "carga alta"
    }

    /// Estado de hoy para resolver qué correcciones aplican.
    struct Conditions: Equatable, Sendable {
        let hrvDeviation: Double?   // hrv/base − 1 (negativo = por debajo de tu base)
        let sleepHours: Double?
        let loadMinutes: Int?
    }

    /// Registros mínimos (~2 semanas) para activar la calibración. Calibrable.
    static let minSamples = 14
    /// Días adversos mínimos para confiar en el offset de un segmento.
    static let minSegmentSamples = 5

    static let identity = RecoveryCalibration(factor: 1, bias: 0, sampleCount: 0, activeToday: [])

    var isActive: Bool { sampleCount >= Self.minSamples }

    init(factor: Double, bias: Double, sampleCount: Int, activeToday: [Condition]) {
        self.factor = factor
        self.bias = bias
        self.sampleCount = sampleCount
        self.activeToday = activeToday
    }

    /// Aprende el ajuste de los check-ins (~4 semanas) y lo resuelve para las condiciones de hoy.
    init(checkIns: [RecoveryCheckIn], today: Conditions) {
        let sample = Array(checkIns.suffix(28))
        guard sample.count >= Self.minSamples else { self = .identity; return }

        func residual(_ c: RecoveryCheckIn) -> Double { Double(c.feeling - c.modelFeeling) }
        let b0 = sample.map(residual).reduce(0, +) / Double(sample.count)
        let loadMedian = Self.median(of: sample.compactMap(\.loadMinutes))

        // Offset de un segmento: media del residual en días adversos − b0 (0 si faltan datos).
        func offset(_ adverse: (RecoveryCheckIn) -> Bool) -> Double {
            let days = sample.filter(adverse)
            guard days.count >= Self.minSegmentSamples else { return 0 }
            return days.map(residual).reduce(0, +) / Double(days.count) - b0
        }
        let hrvOffset   = offset { Self.isLowHRV(Self.deviation($0)) }
        let sleepOffset = offset { Self.isShortSleep($0.sleepHours) }
        let loadOffset  = offset { Self.isHighLoad($0.loadMinutes, median: loadMedian) }

        // Suma los offsets de las condiciones adversas de HOY.
        var todayBias = b0
        var active: [Condition] = []
        if Self.isLowHRV(today.hrvDeviation), hrvOffset != 0 {
            todayBias += hrvOffset; active.append(.lowHRV)
        }
        if Self.isShortSleep(today.sleepHours), sleepOffset != 0 {
            todayBias += sleepOffset; active.append(.shortSleep)
        }
        if Self.isHighLoad(today.loadMinutes, median: loadMedian), loadOffset != 0 {
            todayBias += loadOffset; active.append(.highLoad)
        }

        // Cada nivel de sesgo ≈ 15% de corrección, acotado para no desbocarse.
        let factor = min(max(1 - todayBias * 0.15, 0.6), 1.5)
        self.init(factor: factor, bias: b0, sampleCount: sample.count, activeToday: active)
    }

    // Predicados de segmento (dirección adversa conocida).
    private static func deviation(_ c: RecoveryCheckIn) -> Double? {
        guard let hrv = c.hrv, let base = c.baselineHRV, base > 0 else { return nil }
        return hrv / base - 1
    }
    private static func isLowHRV(_ deviation: Double?) -> Bool { (deviation ?? 0) < -0.05 }
    private static func isShortSleep(_ hours: Double?) -> Bool { (hours ?? 99) < 6.5 }
    private static func isHighLoad(_ load: Int?, median: Double?) -> Bool {
        guard let load, let median else { return false }
        return Double(load) > median
    }
    private static func median(of values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        let mid = s.count / 2
        return s.count.isMultiple(of: 2) ? Double(s[mid - 1] + s[mid]) / 2 : Double(s[mid])
    }

    /// Frase para la UI cuando la calibración está activa.
    var summary: String {
        if !activeToday.isEmpty {
            let cond = activeToday.map(\.rawValue).joined(separator: " y ")
            let dir = factor < 1 ? "recuperarte mejor" : "recuperarte más lento"
            return "Ajustado a ti: hoy (\(cond)) sueles \(dir) de lo previsto (\(sampleCount) registros)."
        }
        switch bias {
        case 0.5...:    return "Ajustado a ti: sueles recuperarte mejor de lo previsto (\(sampleCount) registros)."
        case ..<(-0.5): return "Ajustado a ti: sueles recuperarte más lento de lo previsto (\(sampleCount) registros)."
        default:        return "Calibrado con tus \(sampleCount) registros: el modelo va alineado contigo."
        }
    }
}
