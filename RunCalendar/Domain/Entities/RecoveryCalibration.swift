import Foundation

/// Ajuste personal de la heurística de recuperación, aprendido de tus check-ins:
/// si sistemáticamente te sientes mejor (o peor) de lo que el modelo predijo,
/// corrige las horas estimadas hacia tu realidad.
/// ponytail: corrección de sesgo lineal; si hiciera falta más precisión, el siguiente
/// paso es una regresión sobre HRV/sueño/carga en vez de un solo factor global.
struct RecoveryCalibration: Equatable, Sendable {
    /// Multiplicador sobre las horas necesarias (1 = sin ajuste, <1 recuperas antes).
    let factor: Double
    /// Sesgo promedio (sentido − predicho) en la escala 1–5. >0 = te sientes mejor que el modelo.
    let bias: Double
    /// Check-ins usados para calibrar.
    let sampleCount: Int

    /// Registros mínimos (~2 semanas) para activar la calibración. Calibrable.
    static let minSamples = 14

    static let identity = RecoveryCalibration(factor: 1, bias: 0, sampleCount: 0)

    /// Activa solo con suficientes registros.
    var isActive: Bool { sampleCount >= Self.minSamples }

    /// Aprende el ajuste de los check-ins (usa los más recientes ~4 semanas).
    init(checkIns: [RecoveryCheckIn]) {
        let sample = Array(checkIns.suffix(28))
        guard sample.count >= Self.minSamples else { self = .identity; return }
        let bias = Double(sample.reduce(0) { $0 + ($1.feeling - $1.modelFeeling) }) / Double(sample.count)
        // Cada nivel de sesgo ≈ 15% de corrección, acotado para no desbocarse.
        let factor = min(max(1 - bias * 0.15, 0.6), 1.5)
        self.init(factor: factor, bias: bias, sampleCount: sample.count)
    }

    init(factor: Double, bias: Double, sampleCount: Int) {
        self.factor = factor
        self.bias = bias
        self.sampleCount = sampleCount
    }

    /// Frase corta para la UI cuando la calibración está activa.
    var summary: String {
        switch bias {
        case 0.5...:    return "Ajustado a ti: sueles recuperarte mejor de lo previsto (\(sampleCount) registros)."
        case ..<(-0.5): return "Ajustado a ti: sueles recuperarte más lento de lo previsto (\(sampleCount) registros)."
        default:        return "Calibrado con tus \(sampleCount) registros: el modelo va alineado contigo."
        }
    }
}
