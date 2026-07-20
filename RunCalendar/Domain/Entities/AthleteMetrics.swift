import Foundation

/// Datos actuales del atleta leídos de Salud, para el progreso y las recomendaciones de metas.
struct AthleteMetrics: Sendable, Equatable {
    let vo2max: Double?     // ml·kg⁻¹·min⁻¹
    let weightKg: Double?
    let heightM: Double?
    let ageYears: Int?

    static let empty = AthleteMetrics(vo2max: nil, weightKg: nil, heightM: nil, ageYears: nil)
}

/// Un registro de peso. La fuente es **Salud** (no Firestore): al escribir ahí, el historial
/// y la sincronización con la app Salud salen gratis.
// ponytail: sin colección propia; si algún día hace falta peso en Mac (sin HealthKit), toca persistir.
struct WeightEntry: Sendable, Equatable, Identifiable {
    let date: Date
    let kg: Double

    var id: Date { date }
}
