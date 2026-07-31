import Foundation
import Testing
@testable import RunCalendar

/// Recomposición: peso estancado + cintura bajando es **progreso real** que la báscula esconde.
/// Migrado de `AssessRecompositionUseCase.selfCheck()`, que corría en cada arranque en DEBUG
/// porque no había target de pruebas.
@Suite("AssessRecompositionUseCase · lo que la báscula esconde")
struct RecompositionTests {

    private let assess = AssessRecompositionUseCase()

    private func entries(_ values: [(daysAgo: Int, value: Double)]) -> [MeasurementEntry] {
        let now = Date()
        return values.map {
            MeasurementEntry(
                date: Calendar.current.date(byAdding: .day, value: -$0.daysAgo, to: now) ?? now,
                value: $0.value
            )
        }
    }

    @Test("Peso quieto y cintura bajando es recomposición")
    func detectsRecomposition() {
        let result = assess(weights: entries([(0, 81.7), (28, 82.0)]),   // −0.3 kg
                            waists: entries([(0, 87.0), (28, 90.0)]))    // −3 cm
        #expect(result?.isRecomposition == true)
    }

    @Test("Bajar de peso de verdad no es recomposición, es progreso normal")
    func losingWeightIsNotRecomposition() {
        let result = assess(weights: entries([(0, 78.0), (28, 82.0)]),   // −4 kg
                            waists: entries([(0, 87.0), (28, 90.0)]))
        #expect(result?.isRecomposition == false)
    }

    @Test("Sin cambio de cintura sí es estar estancado")
    func stalledIsStalled() {
        let result = assess(weights: entries([(0, 82.0), (28, 82.0)]),
                            waists: entries([(0, 90.0), (28, 90.0)]))
        #expect(result?.isRecomposition == false)
    }

    @Test("Sin serie de cintura no se concluye nada")
    func noWaistNoConclusion() {
        #expect(assess(weights: entries([(0, 82.0), (28, 83.0)]), waists: []) == nil)
    }

    @Test("Un solo punto dentro de la ventana no compara")
    func outsideTheWindowDoesNotCount() {
        #expect(assess(weights: entries([(0, 81.7), (90, 82.0)]),
                       waists: entries([(0, 87.0), (90, 90.0)])) == nil)
    }
}
