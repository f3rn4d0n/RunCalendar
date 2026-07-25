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

    /// Distancias con récord, en orden.
    static let standard: [RaceDiscipline] = [.fiveK, .tenK, .fifteenK, .halfMarathon, .marathon]

    /// Las mismas distancias en km, para pedirle los tramos a Salud.
    static let targetsKm: [Double] = standard.compactMap(\.standardDistanceKm)

    /// `splits` son los mejores tramos que Salud encontró **dentro** de cualquier corrida
    /// (tu 5K más rápido puede venir de una corrida de 10 km). Vacío en Mac o sin permiso:
    /// ahí el récord se calcula solo con carreras y entrenamientos completos, como antes.
    static func compute(races: [Race], sessions: [TrainingSession],
                        splits: [BestSplit] = []) -> [PersonalRecord] {
        let efforts = raceEfforts(races) + trainingEfforts(sessions, coveredBy: splits) + splitEfforts(splits)
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

    /// Entrenamientos de carrera con distancia y duración, menos los que ya aportaron un tramo:
    /// para esos, el tramo mide lo mismo o mejor y con segundos exactos (la sesión guarda
    /// minutos redondeados), así que la fila del entrenamiento sobra.
    private static func trainingEfforts(_ sessions: [TrainingSession],
                                        coveredBy splits: [BestSplit]) -> [RunEffort] {
        sessions.compactMap { session in
            guard session.type == .running,
                  let km = session.distanceKm, km > 0,
                  let minutes = session.durationMin, minutes > 0,
                  // Mismo entrenamiento de Salud: la sesión se importó con `workout.startDate`.
                  !splits.contains(where: { abs($0.date.timeIntervalSince(session.date)) < 1 })
            else { return nil }
            return RunEffort(id: "train-\(session.id)", source: .training, name: session.title,
                             date: session.date, distanceKm: km, timeSeconds: minutes * 60)
        }
    }

    /// El mejor tramo de cada distancia, tal como lo cuenta el Watch.
    private static func splitEfforts(_ splits: [BestSplit]) -> [RunEffort] {
        splits.map { split in
            let km = split.workoutKm.formatted(.number.precision(.fractionLength(1)))
            return RunEffort(id: "split-\(split.id)", source: .training,
                             name: "dentro de tu corrida de \(km) km",
                             date: split.date, distanceKm: split.distanceKm,
                             timeSeconds: split.seconds)
        }
    }
}
