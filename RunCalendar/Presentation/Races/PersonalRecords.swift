import Foundation

/// Un esfuerzo de carrera (de una carrera registrada o de un entrenamiento importado),
/// con distancia y tiempo, para calcular récords y velocidad.
struct RunEffort: Identifiable {
    enum Source { case race, training }

    let id: String
    let source: Source
    let name: String
    let date: Date
    let distanceKm: Double
    let timeSeconds: Int

    /// Ritmo en segundos por km.
    var paceSecondsPerKm: Int { distanceKm > 0 ? Int(Double(timeSeconds) / distanceKm) : 0 }
    /// Velocidad promedio en km/h.
    var speedKmh: Double { timeSeconds > 0 ? distanceKm / (Double(timeSeconds) / 3600) : 0 }
}

/// Récord personal de una distancia: mejor esfuerzo (por ritmo) y el historial.
struct PersonalRecord: Identifiable {
    let distance: RaceDiscipline
    let best: RunEffort
    let history: [RunEffort]   // cronológico
    var id: String { distance.id }
}

/// Calcula los récords por distancia estándar juntando carreras y entrenamientos.
/// Se rankea por **ritmo** (no por tiempo bruto), para que sea justo comparar esfuerzos
/// de distancias ligeramente distintas (p. ej. una carrera de 10K vs un entreno de 9.8 km).
enum PersonalRecords {
    /// Tolerancia de distancia para asignar un esfuerzo a una distancia estándar (±5%).
    private static let tolerance = 0.05

    static func compute(races: [Race], sessions: [TrainingSession]) -> [PersonalRecord] {
        let efforts = raceEfforts(races) + trainingEfforts(sessions)
        let standard: [RaceDiscipline] = [.fiveK, .tenK, .halfMarathon, .marathon]
        return standard.compactMap { distance in
            guard let target = distance.standardDistanceKm else { return nil }
            let bucket = efforts.filter { abs($0.distanceKm - target) / target <= tolerance }
            guard let best = bucket.min(by: { $0.paceSecondsPerKm < $1.paceSecondsPerKm }) else { return nil }
            return PersonalRecord(distance: distance, best: best, history: bucket.sorted { $0.date < $1.date })
        }
    }

    /// Carreras con tiempo (excluye trail: terreno no comparable con asfalto).
    private static func raceEfforts(_ races: [Race]) -> [RunEffort] {
        races.compactMap { race in
            guard race.discipline != .trail,
                  let time = race.finishTimeSeconds, time > 0,
                  let km = race.distanceKm ?? race.discipline.standardDistanceKm, km > 0
            else { return nil }
            return RunEffort(id: "race-\(race.id)", source: .race, name: race.name,
                             date: race.date, distanceKm: km, timeSeconds: time)
        }
    }

    /// Entrenamientos de carrera con distancia y duración.
    private static func trainingEfforts(_ sessions: [TrainingSession]) -> [RunEffort] {
        sessions.compactMap { session in
            guard session.type == .running,
                  let km = session.distanceKm, km > 0,
                  let minutes = session.durationMin, minutes > 0
            else { return nil }
            return RunEffort(id: "train-\(session.id)", source: .training, name: session.title,
                             date: session.date, distanceKm: km, timeSeconds: minutes * 60)
        }
    }
}
