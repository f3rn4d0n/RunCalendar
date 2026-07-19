import Foundation

/// Datos actuales del atleta leídos de Salud, para el progreso y las recomendaciones de metas.
struct AthleteMetrics: Sendable, Equatable {
    let vo2max: Double?     // ml·kg⁻¹·min⁻¹
    let weightKg: Double?
    let heightM: Double?
    let ageYears: Int?

    static let empty = AthleteMetrics(vo2max: nil, weightKg: nil, heightM: nil, ageYears: nil)
}
