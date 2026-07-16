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

/// Tendencias de condición: volumen semanal, ritmo por corrida y VO₂max en el tiempo.
struct FitnessTrend: Equatable, Sendable {
    let weeklyVolume: [WeeklyVolume]   // últimas semanas, cronológico
    let pace: [RunPacePoint]           // corridas recientes, cronológico
    let vo2Max: [VO2Point]             // ~6 meses, semanal, cronológico
}
