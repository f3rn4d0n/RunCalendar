import Testing
@testable import RunCalendar

/// `BestSplit.fastestWindow`: el récord de una distancia puede vivir **dentro** de una corrida
/// más larga, igual que los récords del Apple Watch.
@Suite("BestSplit · tramo más rápido")
struct BestSplitTests {

    /// Curva a ritmo constante: una muestra cada 6 s / 20 m (5:00/km durante 10 km).
    private let steady: [BestSplit.CurvePoint] = (0...600).map { (Double($0) * 6, Double($0) * 20) }

    @Test("A ritmo constante, el mejor 5K son 25:00 exactos")
    func steadyPace() {
        #expect(BestSplit.fastestWindow(steady, meters: 5000) == 1500)
    }

    @Test("El récord vive dentro de la corrida, no en su promedio")
    func fastestSegmentInsideLongerRun() {
        // 3 km lentos (6:00/km) + 5 km rápidos (4:00/km) + 2 km lentos. El mejor 5K son los 20:00
        // del tramo rápido; el promedio de la corrida daría 26:00.
        var mixed: [BestSplit.CurvePoint] = [(0, 0)]
        func run(km: Double, paceSecPerKm: Double) {
            for _ in 0..<Int(km * 10) {   // una muestra cada 100 m
                let last = mixed[mixed.count - 1]
                mixed.append((last.seconds + paceSecPerKm / 10, last.meters + 100))
            }
        }
        run(km: 3, paceSecPerKm: 360)
        run(km: 5, paceSecPerKm: 240)
        run(km: 2, paceSecPerKm: 360)

        #expect(BestSplit.fastestWindow(mixed, meters: 5000) == 1200)
    }

    @Test("Sin llegar a la distancia no hay récord (no se inventa un tiempo)")
    func noRecordWithoutDistance() {
        #expect(BestSplit.fastestWindow(steady, meters: 21_097.5) == nil)
        #expect(BestSplit.fastestWindow([], meters: 5000) == nil)
    }

    @Test("Se interpola el final entre muestras")
    func interpolatesFinalSample() {
        // 5 km justos entre dos muestras de 500 m a 5:00/km: sin interpolar daría 1650.
        let coarse: [BestSplit.CurvePoint] = (0...22).map { (Double($0) * 150, Double($0) * 500) }
        #expect(BestSplit.fastestWindow(coarse, meters: 5000) == 1500)
    }
}
