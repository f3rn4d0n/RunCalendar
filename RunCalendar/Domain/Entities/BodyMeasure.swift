import Foundation

/// Medida corporal que la app registra en Salud. Peso y cintura comparten mecánica
/// (leer la última, escribir una nueva, listar el historial), por eso van en un solo tipo.
enum BodyMeasure: String, CaseIterable, Identifiable, Sendable {
    case weight = "Peso"
    case waist  = "Cintura"

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Unidad en la que el usuario la captura y la lee.
    var unitLabel: String {
        switch self {
        case .weight: return "kg"
        case .waist:  return "cm"
        }
    }

    var systemImage: String {
        switch self {
        case .weight: return "scalemass"
        case .waist:  return "figure.walk"
        }
    }

    /// Rango sano de captura, para no escribir un dedazo en Salud (datos que otras apps leen).
    var validRange: ClosedRange<Double> {
        switch self {
        case .weight: return 20...400   // kg
        case .waist:  return 40...200   // cm
        }
    }

    func isValid(_ value: Double) -> Bool { validRange.contains(value) }
}

/// Un registro de una medida corporal. La fuente es **Salud**: al escribir ahí, el historial
/// y la sincronización con la app Salud salen gratis.
struct MeasurementEntry: Sendable, Equatable, Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}
