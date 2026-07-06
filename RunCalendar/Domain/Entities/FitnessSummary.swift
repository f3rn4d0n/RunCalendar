import Foundation

/// Resumen de condición física derivado de los datos de Salud (Apple Health).
struct FitnessSummary: Equatable, Sendable {
    /// Ventana analizada, en semanas.
    let weeks: Int
    /// Distancia total corrida en la ventana (km).
    let totalDistanceKm: Double
    /// Promedio semanal de distancia (km) en la ventana.
    let weeklyDistanceKm: Double
    /// Distancia corrida en los últimos 7 días (km).
    let last7DaysKm: Double
    /// Carrera más larga de la ventana (km).
    let longestRunKm: Double
    /// Número de entrenamientos de carrera en la ventana.
    let runCount: Int
    /// Fecha del último entrenamiento de carrera.
    let lastRunDate: Date?
    /// VO₂max estimado (ml/kg·min), si Salud lo tiene.
    let vo2Max: Double?
    /// Frecuencia cardiaca en reposo (lpm), si Salud la tiene.
    let restingHeartRate: Double?
    /// Edad del usuario (años), leída de Salud si está disponible.
    let age: Int?

    static let empty = FitnessSummary(
        weeks: 0, totalDistanceKm: 0, weeklyDistanceKm: 0, last7DaysKm: 0, longestRunKm: 0,
        runCount: 0, lastRunDate: nil, vo2Max: nil, restingHeartRate: nil, age: nil
    )
}
