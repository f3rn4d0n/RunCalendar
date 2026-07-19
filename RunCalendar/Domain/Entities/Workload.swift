import Foundation

/// Minutos de entrenamiento crudos para calcular la relación carga aguda:crónica.
struct WorkloadInput: Sendable {
    let acuteMinutes: Int    // últimos 7 días
    let chronicMinutes: Int  // últimos 28 días
}

/// Zona de la relación carga aguda:crónica (ACWR).
enum WorkloadZone: Sendable {
    case detraining   // < 0.8 — carga baja, se pierde forma
    case optimal      // 0.8–1.3 — zona dulce
    case caution      // 1.3–1.5 — subió rápido
    case highRisk     // > 1.5 — riesgo de lesión

    var title: String {
        switch self {
        case .detraining: return "Carga baja"
        case .optimal:    return "Zona óptima"
        case .caution:    return "Precaución"
        case .highRisk:   return "Riesgo alto"
        }
    }

    var systemImage: String {
        switch self {
        case .detraining: return "arrow.down.circle.fill"
        case .optimal:    return "checkmark.circle.fill"
        case .caution:    return "exclamationmark.circle.fill"
        case .highRisk:   return "exclamationmark.triangle.fill"
        }
    }
}

/// Relación carga aguda:crónica (ACWR): tu carga de la última semana vs. tu promedio
/// semanal de las últimas 4. Métrica estándar para detectar sobrecarga.
struct WorkloadRatio: Equatable, Sendable {
    let acuteMinutes: Int
    let weeklyAverageMinutes: Int
    let ratio: Double
    let zone: WorkloadZone
    let note: String

    var ratioText: String { ratio.formatted(.number.precision(.fractionLength(1))) + "×" }

    /// Llenado del anillo: 1.5× (o más) llena el aro; el color ya distingue la zona.
    var ringFraction: Double { min(ratio / 1.5, 1) }
}
