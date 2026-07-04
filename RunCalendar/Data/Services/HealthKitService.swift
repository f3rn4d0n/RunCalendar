import Foundation
import HealthKit

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
        return types
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

        let vo2 = try? await mostRecentQuantity(.vo2Max, unit: vo2Unit)
        let resting = try? await mostRecentQuantity(.restingHeartRate,
                                                    unit: HKUnit.count().unitDivided(by: .minute()))

        return FitnessSummary(
            weeks: weeks,
            totalDistanceKm: totalKm,
            weeklyDistanceKm: weeks > 0 ? totalKm / Double(weeks) : 0,
            longestRunKm: longest,
            runCount: runs.count,
            lastRunDate: runs.map(\.endDate).max(),
            vo2Max: vo2,
            restingHeartRate: resting
        )
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
