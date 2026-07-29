import Foundation

/// Guarda el review dominical (energía y hambre; lo que Salud no almacena).
struct SaveBodyLogUseCase: Sendable {
    private let repository: BodyLogRepository
    init(repository: BodyLogRepository) { self.repository = repository }

    func callAsFunction(_ log: BodyLog, userID: String) async throws {
        try await repository.save(log, userID: userID)
    }
}

/// Trae los reviews recientes para el historial y para saber si ya tocó el de esta semana.
struct FetchBodyLogsUseCase: Sendable {
    private let repository: BodyLogRepository
    init(repository: BodyLogRepository) { self.repository = repository }

    func callAsFunction(days: Int = 120, userID: String) async throws -> [BodyLog] {
        try await repository.fetchRecent(days: days, userID: userID)
    }
}

/// Detecta **recomposición corporal**: la báscula no se mueve pero la cintura sí baja.
///
/// Es el caso que más desmotiva y el que justifica medir cintura: entrenando ganas músculo
/// mientras pierdes grasa, así que el peso se estanca aunque el progreso sea real. Sin este
/// aviso, la barra de la meta de peso diría "faltan X kg" durante semanas sin explicar nada.
struct AssessRecompositionUseCase: Sendable {

    /// Cambio observado en una ventana de tiempo.
    struct Trend: Equatable, Sendable {
        let weightDeltaKg: Double
        let waistDeltaCm: Double
        /// Peso quieto (±`weightStallKg`) pero cintura bajando al menos `waistDropCm`.
        let isRecomposition: Bool
    }

    // ponytail: umbrales fijos y conservadores. El peso oscila ~1 kg por agua/sal, así que
    // "estancado" tiene que absorber ese ruido; 1 cm de cintura ya está fuera del error de cinta.
    static let weightStallKg = 1.0
    static let waistDropCm = 1.0

    /// Compara el registro más reciente contra el más antiguo dentro de `weeks`.
    /// `nil` si falta alguna de las dos series o no hay dos puntos que comparar.
    func callAsFunction(
        weights: [MeasurementEntry],
        waists: [MeasurementEntry],
        weeks: Int = 6,
        now: Date = Date()
    ) -> Trend? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -weeks * 7, to: now) ?? now
        guard let weightDelta = delta(of: weights, since: cutoff),
              let waistDelta = delta(of: waists, since: cutoff) else { return nil }

        return Trend(
            weightDeltaKg: weightDelta,
            waistDeltaCm: waistDelta,
            isRecomposition: abs(weightDelta) < Self.weightStallKg && waistDelta <= -Self.waistDropCm
        )
    }

    /// Cambio (más reciente − más antiguo) dentro de la ventana. Negativo = bajó.
    /// `nil` si no hay al menos dos registros en la ventana.
    private func delta(of entries: [MeasurementEntry], since cutoff: Date) -> Double? {
        // Las series vienen de Salud ordenadas de más reciente a más vieja.
        let window = entries.filter { $0.date >= cutoff }
        guard let newest = window.first, let oldest = window.last, newest.date != oldest.date else {
            return nil
        }
        return newest.value - oldest.value
    }
}
