import Foundation

/// Zona de frecuencia cardiaca (% de la FC máxima estimada, 220 − edad).
enum HeartRateZone: Int, CaseIterable, Sendable {
    case z1 = 1, z2, z3, z4, z5

    var label: String {
        switch self {
        case .z1: return "Z1 · Recuperación"
        case .z2: return "Z2 · Aeróbico"
        case .z3: return "Z3 · Tempo"
        case .z4: return "Z4 · Umbral"
        case .z5: return "Z5 · Máximo"
        }
    }

    /// Rango como porcentaje de la FC máxima.
    var percentRange: String {
        switch self {
        case .z1: return "50–60%"
        case .z2: return "60–70%"
        case .z3: return "70–80%"
        case .z4: return "80–90%"
        case .z5: return "90–100%"
        }
    }

    /// Zona a partir del BPM y la FC máxima estimada.
    static func from(bpm: Int, maxHR: Int) -> HeartRateZone {
        guard maxHR > 0 else { return .z1 }
        let pct = Double(bpm) / Double(maxHR)
        switch pct {
        case ..<0.6:  return .z1
        case ..<0.7:  return .z2
        case ..<0.8:  return .z3
        case ..<0.9:  return .z4
        default:      return .z5
        }
    }
}

/// Un punto muestreado de la traza GPS de una corrida, con su métrica instantánea.
struct RoutePoint: Identifiable, Sendable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    /// Segundos transcurridos desde el inicio de la corrida.
    let elapsed: TimeInterval
    /// Distancia acumulada desde el inicio hasta este punto, en km.
    let distanceKm: Double
    let speedKmh: Double
    let heartRate: Int?
    let zone: HeartRateZone?
}

/// Traza GPS completa de una corrida leída de Apple Salud (ruta + FC por punto).
struct WorkoutRoute: Sendable {
    let points: [RoutePoint]
    let distanceKm: Double
    let duration: TimeInterval

    var isEmpty: Bool { points.count < 2 }

    /// Rango de BPM de la corrida (para leyendas / resúmenes).
    var heartRateRange: (min: Int, max: Int)? {
        let bpms = points.compactMap(\.heartRate)
        guard let lo = bpms.min(), let hi = bpms.max() else { return nil }
        return (lo, hi)
    }

    /// Parciales por kilómetro completo (tiempo y FC promedio de cada km).
    var splits: [Split] {
        guard points.count >= 2 else { return [] }
        var result: [Split] = []
        var km = 1
        var startElapsed = 0.0
        var hrSum = 0, hrCount = 0
        for point in points {
            if let hr = point.heartRate { hrSum += hr; hrCount += 1 }
            if point.distanceKm >= Double(km) {
                result.append(Split(
                    km: km,
                    seconds: Int(point.elapsed - startElapsed),
                    avgHeartRate: hrCount > 0 ? hrSum / hrCount : nil
                ))
                startElapsed = point.elapsed
                km += 1
                hrSum = 0; hrCount = 0
            }
        }
        return result
    }
}

/// Parcial de un kilómetro: tiempo y FC promedio.
struct Split: Identifiable, Sendable {
    let km: Int
    let seconds: Int
    let avgHeartRate: Int?

    var id: Int { km }
    /// Ritmo del km como "m:ss".
    var paceText: String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}
