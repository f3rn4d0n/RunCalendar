import Foundation
import Testing
@testable import RunCalendar

/// La línea base de HRV a lo largo de meses. Responde "¿me estoy adaptando?", que no es la pregunta
/// del HRV de hoy ("¿puedo apretar?") — y por eso se compara por bloques de semanas, no por días.
@Suite("HRVPoint · la línea base en meses")
struct HRVBaselineTests {

    /// `values` semana a semana, la más vieja primero.
    private func series(_ values: [Double]) -> [HRVPoint] {
        let start = Date().addingTimeInterval(-Double(values.count) * 7 * 86400)
        return values.enumerated().map { index, ms in
            HRVPoint(date: start.addingTimeInterval(Double(index) * 7 * 86400), milliseconds: ms)
        }
    }

    @Test("Sin dos bloques completos no se dice nada")
    func silentWithoutTwoBlocks() {
        for count in 0..<HRVPoint.weeksForVerdict {
            let puntos = series(Array(repeating: 50, count: count))
            #expect(HRVPoint.trend(of: puntos) == .notEnough, "con \(count) semanas ya opina")
        }
    }

    @Test("Una subida sostenida se reconoce")
    func sustainedRiseIsDetected() {
        // 4 semanas en ~50 y 4 en ~60: +20%, muy por encima del ruido semanal.
        let puntos = series([48, 50, 52, 50, 58, 60, 62, 60])
        #expect(HRVPoint.trend(of: puntos) == .rising)
    }

    @Test("Una bajada sostenida también")
    func sustainedFallIsDetected() {
        #expect(HRVPoint.trend(of: series([60, 62, 58, 60, 50, 48, 52, 50])) == .falling)
    }

    @Test("El ruido semanal no se llama tendencia")
    func weeklyNoiseIsNotATrend() {
        // El HRV varía ~5–10% de una semana a otra sin que cambie nada. Llamar "mejora" a eso sería
        // darle al atleta una señal donde no la hay.
        #expect(HRVPoint.trend(of: series([50, 54, 48, 52, 51, 49, 53, 50])) == .stable)
    }

    @Test("Un cambio justo por debajo del umbral es estable, no tendencia")
    func changesUnderTheThresholdAreStable() {
        let base = 50.0
        let apenas = base * (1 + HRVPoint.meaningfulChange * 0.9)
        #expect(HRVPoint.trend(of: series([base, base, base, base,
                                           apenas, apenas, apenas, apenas])) == .stable)
    }

    @Test("El orden de llegada no importa: se ordena por fecha")
    func orderDoesNotMatter() {
        let subiendo = series([48, 50, 52, 50, 58, 60, 62, 60])
        #expect(HRVPoint.trend(of: subiendo.reversed()) == .rising)
        #expect(HRVPoint.trend(of: subiendo.shuffled()) == .rising)
    }

    @Test("Solo pesan los dos últimos bloques, no todo el historial")
    func onlyTheLastTwoBlocksCount() {
        // Un desplome de hace seis meses ya no es noticia: lo que importa es de dónde vienes ahora.
        let conPasadoMalo = series([20, 20, 20, 20, 20, 20, 20, 20,   // hace meses
                                    50, 50, 50, 50, 51, 50, 49, 50])  // los dos bloques recientes
        #expect(HRVPoint.trend(of: conPasadoMalo) == .stable)
    }

    @Test("Una serie en cero no inventa una tendencia")
    func zeroesDoNotDivideByZero() {
        #expect(HRVPoint.trend(of: series(Array(repeating: 0, count: 8))) == .notEnough)
    }
}
