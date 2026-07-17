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
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
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

    func fetchRecovery() async throws -> RecoverySnapshot? {
        guard isAvailable() else { return nil }
        let hrvUnit = HKUnit.secondUnit(with: .milli)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        async let currentHRV = averageQuantity(.heartRateVariabilitySDNN, unit: hrvUnit, days: 3)
        async let baselineHRV = averageQuantity(.heartRateVariabilitySDNN, unit: hrvUnit, days: 60)
        async let restingHR = averageQuantity(.restingHeartRate, unit: bpmUnit, days: 7)
        async let baselineRHR = averageQuantity(.restingHeartRate, unit: bpmUnit, days: 60)
        async let sleep = lastNightSleepHours()
        let load = try await recentWorkoutLoad(hours: 72)

        return RecoverySnapshot(
            currentHRV: (try? await currentHRV) ?? nil,
            baselineHRV: (try? await baselineHRV) ?? nil,
            restingHR: (try? await restingHR) ?? nil,
            baselineRestingHR: (try? await baselineRHR) ?? nil,
            recentLoadMinutes: load.minutes,
            hoursSinceLastWorkout: load.lastEnd.map { Date().timeIntervalSince($0) / 3600 },
            lastNightSleepHours: (try? await sleep) ?? nil
        )
    }

    func fetchFitnessTrend(weeks: Int) async throws -> FitnessTrend? {
        guard isAvailable() else { return nil }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7 * weeks, to: calendar.startOfDay(for: Date())) ?? Date()
        let runs = try await runningWorkouts(since: start)

        // VO₂max: promedio semanal de los últimos ~6 meses (se mueve lento).
        async let vo2 = weeklyVO2Series(weeks: 26)

        // Volumen: km por semana (semana que empieza el lunes), cronológico.
        var kmByWeek: [Date: Double] = [:]
        for run in runs {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: run.startDate)?.start
                ?? calendar.startOfDay(for: run.startDate)
            kmByWeek[weekStart, default: 0] += workoutDistanceKm(run)
        }
        let weeklyVolume = kmByWeek
            .map { WeeklyVolume(weekStart: $0.key, km: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }

        // Ritmo por corrida (con distancia y duración válidas), cronológico.
        let pace = runs
            .compactMap { run -> RunPacePoint? in
                let km = workoutDistanceKm(run)
                guard km > 0, run.duration > 0 else { return nil }
                return RunPacePoint(
                    id: run.uuid.uuidString,
                    date: run.startDate,
                    paceSecondsPerKm: Int(run.duration / km),
                    distanceKm: km
                )
            }
            .sorted { $0.date < $1.date }

        return FitnessTrend(weeklyVolume: weeklyVolume, pace: pace, vo2Max: try await vo2)
    }

    /// Promedio semanal de VO₂max de las últimas `weeks` semanas (solo semanas con dato).
    private func weeklyVO2Series(weeks: Int) async throws -> [VO2Point] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return [] }
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -7 * weeks, to: anchor) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        var interval = DateComponents(); interval.weekOfYear = 1
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type, quantitySamplePredicate: predicate,
                options: .discreteAverage, anchorDate: anchor, intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                var result: [VO2Point] = []
                collection?.enumerateStatistics(from: start, to: Date()) { stat, _ in
                    if let avg = stat.averageQuantity()?.doubleValue(for: self.vo2Unit) {
                        result.append(VO2Point(date: stat.startDate, value: avg))
                    }
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    func fetchWorkload() async throws -> WorkloadInput? {
        guard isAvailable() else { return nil }
        async let acute = recentWorkoutLoad(hours: 7 * 24)
        async let chronic = recentWorkoutLoad(hours: 28 * 24)
        return WorkloadInput(
            acuteMinutes: try await acute.minutes,
            chronicMinutes: try await chronic.minutes
        )
    }

    func fetchRecoveryTrend(days: Int) async throws -> RecoveryTrend? {
        guard isAvailable() else { return nil }
        let calendar = Calendar.current
        async let hrvSeries = dailyHRVSeries(days: days)
        async let sleepSeries = dailySleepSeries(days: days)
        async let training = trainingDaysSet(days: days)
        let baseline = (try? await averageQuantity(.heartRateVariabilitySDNN,
                                                    unit: .secondUnit(with: .milli), days: 60)) ?? nil
        let hrv = try await hrvSeries
        let sleep = try await sleepSeries
        let trainingDays = try await training

        let points: [RecoveryTrendPoint] = (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date()))
            else { return nil }
            return RecoveryTrendPoint(date: day, hrv: hrv[day], sleepHours: sleep[day])
        }
        return RecoveryTrend(points: points, hrvBaseline: baseline, trainingDays: Array(trainingDays))
    }

    /// Promedio diario de HRV (SDNN, ms) por día.
    private func dailyHRVSeries(days: Int) async throws -> [Date: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [:] }
        let unit = HKUnit.secondUnit(with: .milli)
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -days, to: anchor) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        var interval = DateComponents(); interval.day = 1
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type, quantitySamplePredicate: predicate,
                options: .discreteAverage, anchorDate: anchor, intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                var result: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: Date()) { stat, _ in
                    if let avg = stat.averageQuantity()?.doubleValue(for: unit) {
                        result[calendar.startOfDay(for: stat.startDate)] = avg
                    }
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    /// Horas dormidas por noche, asignadas al día en que despertaste.
    private func dailySleepSeries(days: Int) async throws -> [Date: Double] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        var byDay: [Date: Double] = [:]
        for sample in samples where asleep.contains(sample.value) {
            let day = calendar.startOfDay(for: sample.endDate)
            byDay[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600
        }
        return byDay
    }

    /// Días (a medianoche) con al menos un entrenamiento en la ventana.
    private func trainingDaysSet(days: Int) async throws -> Set<Date> {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        return Set(workouts.map { calendar.startOfDay(for: $0.startDate) })
    }

    /// Horas dormidas la última noche (suma de etapas "dormido" en las últimas 24 h).
    // ponytail: si hay varias fuentes de sueño (Watch + otra app) podría sumar de más;
    // suficiente para un proxy de recuperación.
    private func lastNightSleepHours() async throws -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        let seconds = samples
            .filter { asleep.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return seconds > 0 ? seconds / 3600 : nil
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
                    durationMin: workout.duration > 0 ? Int(workout.duration / 60) : nil,
                    avgHeartRate: averageHeartRate(of: workout)
                )
            }
            .filter { $0.distanceKm > 0 }
            .sorted { $0.date > $1.date }
    }

    /// FC promedio del workout, de sus estadísticas (nil si no la registró).
    private func averageHeartRate(of workout: HKWorkout) -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let avg = workout.statistics(for: type)?.averageQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        else { return nil }
        return Int(avg.rounded())
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
        // Distancia acumulada punto a punto (recta entre muestras GPS; con ~800 puntos
        // los tramos son cortos y el error vs. la trayectoria real es despreciable).
        var cumulativeMeters = 0.0
        var previous: CLLocation?
        let points: [RoutePoint] = sampled.map { loc in
            if let previous { cumulativeMeters += loc.distance(from: previous) }
            previous = loc
            let bpm = nearestHeartRate(heartRates, at: loc.timestamp, from: &hrIndex)
            let speedKmh = loc.speed >= 0 ? loc.speed * 3.6 : 0
            var zone: HeartRateZone?
            if let bpm, let maxHR { zone = HeartRateZone.from(bpm: bpm, maxHR: maxHR) }
            return RoutePoint(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                elapsed: loc.timestamp.timeIntervalSince(t0),
                distanceKm: cumulativeMeters / 1000,
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

    /// Promedio de una cantidad en los últimos `days` días (nil si no hay muestras).
    private func averageQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage
            ) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    /// Minutos de entrenamiento (cualquier tipo) y fin del último, en las últimas `hours` horas.
    private func recentWorkoutLoad(hours: Int) async throws -> (minutes: Int, lastEnd: Date?) {
        let start = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        let minutes = Int(workouts.reduce(0) { $0 + $1.duration } / 60)
        return (minutes, workouts.map(\.endDate).max())
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
