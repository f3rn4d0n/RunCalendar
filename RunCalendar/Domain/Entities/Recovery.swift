import Foundation

/// Datos crudos de Salud para estimar la recuperación.
struct RecoverySnapshot: Sendable {
    /// HRV (SDNN, ms) reciente: promedio de los últimos ~3 días.
    let currentHRV: Double?
    /// HRV base: promedio de ~60 días (tu normal).
    let baselineHRV: Double?
    /// FC en reposo reciente (lpm).
    let restingHR: Double?
    /// FC en reposo base (~60 días).
    let baselineRestingHR: Double?
    /// Minutos de entrenamiento (cualquier tipo) en las últimas 72 h.
    let recentLoadMinutes: Int
    /// Horas desde el último entrenamiento.
    let hoursSinceLastWorkout: Double?
    /// Horas dormidas la última noche (Salud), si las hay.
    let lastNightSleepHours: Double?
}

/// Nivel de recuperación estimado.
enum RecoveryLevel: String, Sendable {
    case recovered = "Recuperado"
    case partial   = "Recuperación parcial"
    case fatigued  = "Fatiga"

    var systemImage: String {
        switch self {
        case .recovered: return "checkmark.seal.fill"
        case .partial:   return "clock.badge.checkmark"
        case .fatigued:  return "bolt.heart.fill"
        }
    }
}

/// Estimación **orientativa** de recuperación (no es consejo médico).
struct RecoveryEstimate: Equatable, Sendable {
    let level: RecoveryLevel
    /// Horas estimadas hasta estar recuperado (0 si ya lo estás).
    let remainingHours: Int
    let currentHRV: Double?
    let baselineHRV: Double?
    /// Desviación del HRV vs. tu base, en % (negativo = por debajo de lo normal).
    let hrvDeviationPct: Double?
    /// Horas dormidas la última noche, si Salud las tiene.
    let sleepHours: Double?
    let note: String
    let tips: [String]
    /// Ajuste personal aplicado (nil si aún no hay suficientes registros para calibrar).
    var calibration: RecoveryCalibration?

    /// "Listo", "~8 h", "~1 día 4 h".
    var remainingText: String {
        guard remainingHours > 0 else { return "Listo" }
        if remainingHours < 24 { return "~\(remainingHours) h" }
        let days = remainingHours / 24, hours = remainingHours % 24
        return hours == 0 ? "~\(days) d" : "~\(days) d \(hours) h"
    }
}

/// Un día de la serie de tendencia: HRV promedio y horas dormidas esa noche.
struct RecoveryTrendPoint: Equatable, Sendable, Identifiable {
    let date: Date
    let hrv: Double?
    let sleepHours: Double?
    var id: Date { date }
}

/// Serie de HRV y sueño de los últimos días, con la base de HRV y los días con entrenamiento.
struct RecoveryTrend: Equatable, Sendable {
    let points: [RecoveryTrendPoint]
    let hrvBaseline: Double?
    let trainingDays: [Date]

    var hrvValues: [RecoveryTrendPoint] { points.filter { $0.hrv != nil } }
    var sleepValues: [RecoveryTrendPoint] { points.filter { $0.sleepHours != nil } }

    /// Veredicto del periodo: ¿en promedio vas por buen camino o acumulando fatiga?
    /// Se basa en tu HRV promedio vs. tu base (y matiza con el sueño). `nil` sin datos.
    var assessment: RecoveryTrendAssessment? {
        let hrvs = points.compactMap(\.hrv)
        guard hrvs.count >= 3, let baseline = hrvBaseline, baseline > 0 else { return nil }
        let average = hrvs.reduce(0, +) / Double(hrvs.count)
        let deviation = (average / baseline - 1) * 100

        let sleeps = points.compactMap(\.sleepHours)
        let avgSleep = sleeps.isEmpty ? nil : sleeps.reduce(0, +) / Double(sleeps.count)
        let sleepsShort = (avgSleep ?? 8) < 6.5

        let verdict: TrendVerdict
        let headline: String
        var message: String
        switch deviation {
        case 3...:
            verdict = .onTrack
            headline = "Vas por buen camino"
            message = "En promedio tu HRV está por encima de tu base: estás tomando buenas decisiones y "
                + "tu cuerpo se está recuperando bien. Mantén este plan y no descuides el descanso."
        case -3..<3:
            verdict = .steady
            headline = "Estás equilibrado"
            message = "Tu HRV se mantiene cerca de tu base. Vas estable; ajusta la carga según cómo te sientas "
                + "y sigue durmiendo bien."
        default:
            verdict = .overreaching
            headline = "Ojo: estás acumulando fatiga"
            message = "En promedio tu HRV está por debajo de tu base, señal de que no te recuperas lo suficiente. "
                + "Baja la intensidad unos días y prioriza el descanso."
        }
        if sleepsShort {
            message += " Además dormiste poco en promedio: apunta a 7–9 h, es lo que más ayuda a tu HRV."
        }

        return RecoveryTrendAssessment(
            verdict: verdict, headline: headline, message: message,
            hrvAverage: average, baseline: baseline, deviationPct: deviation
        )
    }
}

/// Veredicto de la tendencia según el HRV promedio vs. la base.
enum TrendVerdict: Sendable {
    case onTrack       // por encima de tu base
    case steady        // alrededor de tu base
    case overreaching  // por debajo de tu base

    var systemImage: String {
        switch self {
        case .onTrack:      return "checkmark.circle.fill"
        case .steady:       return "equal.circle.fill"
        case .overreaching: return "exclamationmark.triangle.fill"
        }
    }
}

struct RecoveryTrendAssessment: Sendable {
    let verdict: TrendVerdict
    let headline: String
    let message: String
    let hrvAverage: Double
    let baseline: Double
    let deviationPct: Double
}
