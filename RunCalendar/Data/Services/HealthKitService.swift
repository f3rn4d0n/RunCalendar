import Foundation
import HealthKit
import CoreLocation

/// Implementación de `HealthRepository` sobre HealthKit.
/// Solo lectura; no escribe nada en Salud. No disponible en Mac.
final class HealthKitService: HealthRepository, @unchecked Sendable {

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let vo2 = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2)
        }
        if let resting = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(resting)
        }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        types.insert(HKSeriesType.workoutRoute())
        if let dob = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dob)
        }
        return types
    }

    /// Edad del usuario a partir de su fecha de nacimiento en Salud (si está autorizada).
    private func currentAge() -> Int? {
        guard let components = try? store.dateOfBirthComponents(),
              let birthDate = Calendar.current.date(from: components) else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    func isAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            Log.health.info("Autorización de Salud solicitada")
            return true
        } catch {
            Log.health.error("Error de autorización de Salud: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func fetchSummary(weeks: Int) async throws -> FitnessSummary {
        guard isAvailable() else { return .empty }
        let start = Calendar.current.date(byAdding: .day, value: -7 * weeks, to: Date()) ?? Date()

        let runs = try await runningWorkouts(since: start)
        let distances = runs.map { workoutDistanceKm($0) }
        let totalKm = distances.reduce(0, +)
        let longest = distances.max() ?? 0

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? start
        let last7Km = runs
            .filter { $0.endDate >= sevenDaysAgo }
            .reduce(0.0) { $0 + workoutDistanceKm($1) }

        let vo2 = try? await mostRecentQuantity(.vo2Max, unit: vo2Unit)
        let resting = try? await mostRecentQuantity(.restingHeartRate,
                                                    unit: HKUnit.count().unitDivided(by: .minute()))

        return FitnessSummary(
            weeks: weeks,
            totalDistanceKm: totalKm,
            weeklyDistanceKm: weeks > 0 ? totalKm / Double(weeks) : 0,
            last7DaysKm: last7Km,
            longestRunKm: longest,
            runCount: runs.count,
            lastRunDate: runs.map(\.endDate).max(),
            vo2Max: vo2,
            restingHeartRate: resting,
            age: currentAge()
        )
    }

    func fetchRecentWorkouts(days: Int) async throws -> [HealthWorkout] {
        guard isAvailable() else { return [] }
        // days <= 0 => todo el historial de Salud (sin límite de fecha).
        let start = days > 0
            ? (Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date())
            : .distantPast
        let runs = try await runningWorkouts(since: start)
        return runs
            .map { workout in
                HealthWorkout(
                    id: workout.uuid.uuidString,
                    date: workout.startDate,
                    distanceKm: workoutDistanceKm(workout),
                    durationMin: workout.duration > 0 ? Int(workout.duration / 60) : nil
                )
            }
            .filter { $0.distanceKm > 0 }
            .sorted { $0.date > $1.date }
    }

    func fetchRoute(onDay date: Date, distanceKm: Double?) async throws -> WorkoutRoute? {
        guard isAvailable() else { return nil }
        // La ruta y la FC son tipos de lectura agregados después: si el usuario
        // autorizó Salud antes, están "sin determinar" y la lectura vuelve vacía.
        // Pedir aquí muestra la hoja para esos tipos la primera vez (idempotente).
        _ = await requestAuthorization()
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let runs = try await runningWorkouts(since: dayStart)
            .filter { $0.startDate < dayEnd }
        Log.health.info("fetchRoute: \(runs.count, privacy: .public) corridas el \(dayStart, privacy: .public) (busco ~\(distanceKm ?? -1, privacy: .public) km)")
        guard let workout = bestMatch(runs, distanceKm: distanceKm) else {
            Log.health.info("fetchRoute: sin corrida ese día → nil")
            return nil
        }

        let workoutKm = workoutDistanceKm(workout)
        let source = workout.sourceRevision.source.name
        let locations = try await routeLocations(for: workout)
        Log.health.info("fetchRoute: workout \(workoutKm, privacy: .public) km grabado por '\(source, privacy: .public)' → \(locations.count, privacy: .public) puntos GPS")
        guard locations.count >= 2 else {
            Log.health.info("fetchRoute: workout sin ruta GPS (¿indoor o sin permiso de Ruta?) → nil")
            return nil
        }

        // FC del intervalo (ascendente por tiempo) y FC máx estimada por edad.
        let heartRates = await heartRateSamples(start: workout.startDate, end: workout.endDate)
        Log.health.info("fetchRoute: \(heartRates.count, privacy: .public) muestras de FC")
        let maxHR = currentAge().map { 220 - $0 }

        let sampled = downsample(locations, max: 800)
        let t0 = sampled.first?.timestamp ?? workout.startDate
        var hrIndex = 0
        let points: [RoutePoint] = sampled.map { loc in
            let bpm = nearestHeartRate(heartRates, at: loc.timestamp, from: &hrIndex)
            let speedKmh = loc.speed >= 0 ? loc.speed * 3.6 : 0
            var zone: HeartRateZone?
            if let bpm, let maxHR { zone = HeartRateZone.from(bpm: bpm, maxHR: maxHR) }
            return RoutePoint(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                elapsed: loc.timestamp.timeIntervalSince(t0),
                speedKmh: speedKmh,
                heartRate: bpm,
                zone: zone
            )
        }
        return WorkoutRoute(
            points: points,
            distanceKm: workoutDistanceKm(workout),
            duration: workout.duration
        )
    }

    func workoutUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            guard isAvailable() else { continuation.finish(); return }
            let query = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { _, handler, error in
                if error == nil { continuation.yield(()) }
                handler()
            }
            store.execute(query)
            continuation.onTermination = { [store] _ in store.stop(query) }
        }
    }

    // MARK: - Queries

    private var vo2Unit: HKUnit {
        HKUnit(from: "ml/kg*min")
    }

    private func workoutDistanceKm(_ workout: HKWorkout) -> Double {
        (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000
    }

    private func runningWorkouts(since start: Date) async throws -> [HKWorkout] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        ])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    /// Corrida del día que mejor coincide: por distancia si se conoce, si no la más larga.
    private func bestMatch(_ runs: [HKWorkout], distanceKm: Double?) -> HKWorkout? {
        guard !runs.isEmpty else { return nil }
        guard let target = distanceKm, target > 0 else {
            return runs.max { workoutDistanceKm($0) < workoutDistanceKm($1) }
        }
        return runs.min { abs(workoutDistanceKm($0) - target) < abs(workoutDistanceKm($1) - target) }
    }

    /// Puntos GPS de la ruta del entrenamiento, ordenados por tiempo.
    private func routeLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        let routes = try await routeSamples(for: workout)
        Log.health.info("routeLocations: \(routes.count, privacy: .public) muestras de ruta (HKWorkoutRoute)")
        var all: [CLLocation] = []
        for route in routes {
            all.append(contentsOf: try await locations(from: route))
        }
        return all.sorted { $0.timestamp < $1.timestamp }
    }

    private func routeSamples(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        let predicate = HKQuery.predicateForObjects(from: workout)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }
    }

    private func locations(from route: HKWorkoutRoute) async throws -> [CLLocation] {
        try await withCheckedThrowingContinuation { continuation in
            var collected: [CLLocation] = []
            let query = HKWorkoutRouteQuery(route: route) { _, batch, done, error in
                if let error { continuation.resume(throwing: error); return }
                if let batch { collected.append(contentsOf: batch) }
                if done { continuation.resume(returning: collected) }
            }
            store.execute(query)
        }
    }

    private func heartRateSamples(start: Date, end: Date) async -> [(date: Date, bpm: Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort
            ) { _, samples, _ in
                let values = (samples as? [HKQuantitySample])?.map {
                    (date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit))
                } ?? []
                continuation.resume(returning: values)
            }
            store.execute(query)
        }
    }

    /// BPM más cercano en el tiempo. `cursor` avanza monótonamente (ambas listas ordenadas).
    private func nearestHeartRate(
        _ samples: [(date: Date, bpm: Double)], at time: Date, from cursor: inout Int
    ) -> Int? {
        guard !samples.isEmpty else { return nil }
        while cursor < samples.count - 1 && samples[cursor + 1].date <= time { cursor += 1 }
        let current = samples[cursor]
        // Elige el vecino más cercano entre el actual y el siguiente.
        if cursor < samples.count - 1 {
            let next = samples[cursor + 1]
            if abs(next.date.timeIntervalSince(time)) < abs(current.date.timeIntervalSince(time)) {
                return Int(next.bpm.rounded())
            }
        }
        return Int(current.bpm.rounded())
    }

    /// Reduce la traza a lo más `max` puntos con muestreo uniforme (mapa fluido).
    private func downsample(_ locations: [CLLocation], max: Int) -> [CLLocation] {
        guard locations.count > max, max > 1 else { return locations }
        let stride = Double(locations.count - 1) / Double(max - 1)
        return (0..<max).map { locations[Int((Double($0) * stride).rounded())] }
    }

    private func mostRecentQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: nil, limit: 1, sortDescriptors: sort
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
