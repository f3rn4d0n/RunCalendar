import Foundation
import Testing
@testable import RunCalendar

/// `AssessRecoveryUseCase` es un **modelo heurístico** con constantes sin calibrar contra datos
/// reales de nadie. Por eso aquí no se fija ningún valor ("14 h con esta entrada"): se prueban
/// **propiedades** que deben cumplirse sea cual sea la calibración futura.
///
/// Una prueba de valor se rompería en cada recalibración legítima y enseñaría a actualizar el
/// número sin pensar; una de propiedad se rompe solo cuando el modelo empieza a mentir.
@Suite("AssessRecoveryUseCase · propiedades del modelo")
struct RecoveryTests {

    private let assess = AssessRecoveryUseCase()

    private func snapshot(loadMinutes: Int = 300, hrv: Double? = nil, baselineHRV: Double? = 60,
                          restingHR: Double? = nil, baselineRestingHR: Double? = 50,
                          sleep: Double? = nil, hoursSince: Double? = 0) -> RecoverySnapshot {
        RecoverySnapshot(currentHRV: hrv, baselineHRV: baselineHRV,
                         restingHR: restingHR, baselineRestingHR: baselineRestingHR,
                         recentLoadMinutes: loadMinutes, hoursSinceLastWorkout: hoursSince,
                         lastNightSleepHours: sleep)
    }

    // MARK: - Acotamiento

    @Test("El estimado nunca pasa del techo, con todo en contra a la vez")
    func neverExceedsCeiling() {
        // El peor día posible: carga altísima, HRV hundida, FC elevada y casi sin dormir.
        // Antes el tope se aplicaba a las horas de carga y **después** se multiplicaba por los
        // factores, así que esto daba ~193 h (8 días) y el anillo de Hoy lo mostraba tal cual.
        let worst = snapshot(loadMinutes: 5000, hrv: 30, baselineHRV: 60,
                             restingHR: 70, baselineRestingHR: 50, sleep: 3)
        let hours = assess(worst).remainingHours
        #expect(hours <= Int(AssessRecoveryUseCase.maxRecoveryHours),
                "estimó \(hours) h (\(hours / 24) días)")
    }

    @Test("Tampoco lo pasa con la calibración empujando al máximo")
    func ceilingHoldsWithCalibration() {
        let worst = snapshot(loadMinutes: 5000, hrv: 30, baselineHRV: 60,
                             restingHR: 70, baselineRestingHR: 50, sleep: 3)
        let maxed = RecoveryCalibration(factor: 1.5, bias: -3, sampleCount: 20, activeToday: [])
        let hours = assess(worst, calibration: maxed).remainingHours
        #expect(hours <= Int(AssessRecoveryUseCase.maxRecoveryHours),
                "estimó \(hours) h (\(hours / 24) días)")
    }

    @Test("Nunca devuelve horas negativas")
    func neverNegative() {
        // Mucho tiempo desde el último entreno: ya pasó de sobra.
        #expect(assess(snapshot(loadMinutes: 60, hoursSince: 500)).remainingHours >= 0)
    }

    // MARK: - Monotonía (la dirección del consejo no puede invertirse)

    @Test("Peor HRV nunca da menos horas de recuperación")
    func worseHRVNeverRecoversFaster() {
        let hrvs: [Double] = [70, 62, 58, 52, 40]   // de mejor a peor contra una base de 60
        let hours = hrvs.map { assess(snapshot(hrv: $0)).remainingHours }
        for (better, worse) in zip(hours, hours.dropFirst()) {
            #expect(worse >= better, "HRV peor devolvió menos horas: \(hours)")
        }
    }

    @Test("Dormir menos nunca da menos horas de recuperación")
    func lessSleepNeverRecoversFaster() {
        let sleeps: [Double] = [9, 8, 7, 6, 4]
        let hours = sleeps.map { assess(snapshot(sleep: $0)).remainingHours }
        for (better, worse) in zip(hours, hours.dropFirst()) {
            #expect(worse >= better, "menos sueño devolvió menos horas: \(hours)")
        }
    }

    @Test("Más carga nunca da menos horas de recuperación")
    func moreLoadNeverRecoversFaster() {
        let loads = [30, 120, 300, 600]
        let hours = loads.map { assess(snapshot(loadMinutes: $0)).remainingHours }
        for (less, more) in zip(hours, hours.dropFirst()) {
            #expect(more >= less, "más carga devolvió menos horas: \(hours)")
        }
    }

    @Test("FC en reposo elevada nunca da menos horas de recuperación")
    func higherRestingHRNeverRecoversFaster() {
        let normal = assess(snapshot(restingHR: 50, baselineRestingHR: 50)).remainingHours
        let elevated = assess(snapshot(restingHR: 60, baselineRestingHR: 50)).remainingHours
        #expect(elevated >= normal)
    }

    // MARK: - Ausencia de datos

    @Test("Sin ningún dato de Salud no se afirma nada optimista de más")
    func missingDataIsNotOptimism() {
        // Sin HRV, sin FC y sin sueño el modelo solo tiene la carga: debe seguir pidiendo
        // recuperación, no declarar "listo" por falta de evidencia.
        let blind = RecoverySnapshot(currentHRV: nil, baselineHRV: nil,
                                     restingHR: nil, baselineRestingHR: nil,
                                     recentLoadMinutes: 600, hoursSinceLastWorkout: 0,
                                     lastNightSleepHours: nil)
        #expect(assess(blind).remainingHours > 0)
    }

    @Test("La nota lo dice cuando no hay HRV, en vez de fingir precisión")
    func explainsMissingHRV() {
        #expect(assess(snapshot(hrv: nil)).note.contains("Sin datos de HRV"))
    }

    // MARK: - Coherencia del nivel

    @Test("El nivel concuerda con las horas restantes")
    func levelMatchesRemainingHours() {
        for load in [0, 60, 300, 1000, 5000] {
            let estimate = assess(snapshot(loadMinutes: load, sleep: 5))
            switch estimate.level {
            case .recovered: #expect(estimate.remainingHours == 0)
            case .partial:   #expect((1...12).contains(estimate.remainingHours))
            case .fatigued:  #expect(estimate.remainingHours > 12)
            }
        }
    }
}

/// La calibración aprende de los check-ins. Igual que arriba: propiedades, no valores — el 15%
/// por nivel de sesgo y el clamp `[0.6, 1.5]` son constantes calibrables.
@Suite("RecoveryCalibration · propiedades del ajuste")
struct RecoveryCalibrationTests {

    private func checkIns(count: Int, feeling: Int, predicted: Int,
                          hrv: Double? = 60, baselineHRV: Double? = 60,
                          sleep: Double? = 8, load: Int? = 100) -> [RecoveryCheckIn] {
        (0..<count).map { i in
            RecoveryCheckIn(
                date: Date().addingTimeInterval(-Double(i) * 86_400),
                feeling: feeling, predictedRemainingHours: predicted,
                hrv: hrv, baselineHRV: baselineHRV, sleepHours: sleep, loadMinutes: load
            )
        }
    }

    private let neutral = RecoveryCalibration.Conditions(hrvDeviation: 0, sleepHours: 8,
                                                         loadMinutes: 100)

    @Test("Sin registros suficientes no se calibra: identidad")
    func notEnoughSamples() {
        let few = checkIns(count: RecoveryCalibration.minSamples - 1, feeling: 2, predicted: 0)
        let calibration = RecoveryCalibration(checkIns: few, today: neutral)
        #expect(calibration == .identity)
        #expect(!calibration.isActive)
        #expect(calibration.factor == 1)
    }

    @Test("Sin residual el ajuste es exactamente 1: no se toca lo que ya acierta")
    func perfectModelIsUntouched() {
        // predicted 0 h => modelFeeling 5. Si el atleta también reporta 5, el residual es 0.
        let accurate = checkIns(count: 20, feeling: 5, predicted: 0)
        let calibration = RecoveryCalibration(checkIns: accurate, today: neutral)
        #expect(calibration.factor == 1)
        #expect(calibration.bias == 0)
        #expect(calibration.isActive)
    }

    @Test("El factor respeta el clamp aunque el sesgo sea extremo", arguments: [
        (feeling: 1, predicted: 0),    // el modelo dice "listo" y el atleta está agotado
        (feeling: 5, predicted: 200)   // el modelo dice "fundido" y el atleta está fresco
    ])
    func factorStaysClamped(scenario: (feeling: Int, predicted: Int)) {
        let extreme = checkIns(count: 28, feeling: scenario.feeling, predicted: scenario.predicted)
        let factor = RecoveryCalibration(checkIns: extreme, today: neutral).factor
        #expect(factor >= 0.6)
        #expect(factor <= 1.5)
    }

    @Test("Si el atleta se siente peor de lo previsto, el ajuste alarga la recuperación")
    func worseThanPredictedLengthensRecovery() {
        // predicted 0 h => el modelo esperaba 5; el atleta reporta 2 => residual negativo.
        let optimistic = checkIns(count: 20, feeling: 2, predicted: 0)
        let calibration = RecoveryCalibration(checkIns: optimistic, today: neutral)
        #expect(calibration.bias < 0)
        #expect(calibration.factor > 1, "debe pedir más horas, no menos")
    }

    @Test("Y al revés: si se siente mejor de lo previsto, la acorta")
    func betterThanPredictedShortensRecovery() {
        let pessimistic = checkIns(count: 20, feeling: 5, predicted: 200)
        let calibration = RecoveryCalibration(checkIns: pessimistic, today: neutral)
        #expect(calibration.bias > 0)
        #expect(calibration.factor < 1)
    }

    @Test("La calibración solo se aplica a partir del mínimo de registros")
    func activatesAtThreshold() {
        let below = checkIns(count: RecoveryCalibration.minSamples - 1, feeling: 2, predicted: 0)
        let at = checkIns(count: RecoveryCalibration.minSamples, feeling: 2, predicted: 0)
        #expect(!RecoveryCalibration(checkIns: below, today: neutral).isActive)
        #expect(RecoveryCalibration(checkIns: at, today: neutral).isActive)
    }
}
