// Check de BestSplit.fastestWindow. Compila contra el archivo real (no duplica la lógica) y
// no necesita simulador ni target de tests. Desde la raíz del repo:
//
//   swiftc RunCalendar/Domain/Entities/BestSplit.swift Scripts/check-best-split.swift \
//     -module-name check -o /tmp/check-best-split && /tmp/check-best-split
//
// Sin -O a propósito: en release los `assert` se compilan fuera y el check no verificaría nada.

@main struct CheckBestSplit {
    static func main() {
        // 1) Ritmo constante de 5:00/km durante 10 km: el mejor 5K son 25:00 exactos.
        let steady: [BestSplit.CurvePoint] = (0...600).map { (Double($0) * 6, Double($0) * 20) }
        assert(BestSplit.fastestWindow(steady, meters: 5000) == 1500,
               "5K a ritmo constante: \(BestSplit.fastestWindow(steady, meters: 5000) ?? -1)")

        // 2) El caso que motivó todo: el récord vive DENTRO de la corrida. 3 km lentos (6:00/km),
        //    5 km rápidos (4:00/km), 2 km lentos. El mejor 5K son los 20:00 del tramo rápido,
        //    no el promedio de la corrida (que daría 26:00).
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
        let best5k = BestSplit.fastestWindow(mixed, meters: 5000)
        assert(best5k == 1200, "5K dentro de una corrida de 10 km: \(best5k ?? -1) (esperaba 1200)")

        // 3) Nunca llegó a la distancia => sin récord (no un tiempo inventado con lo que sí corrió).
        assert(BestSplit.fastestWindow(steady, meters: 21_097.5) == nil, "10 km no tienen un 21K")
        assert(BestSplit.fastestWindow([], meters: 5000) == nil, "curva vacía")

        // 4) Se interpola el final: 5 km justos entre dos muestras de 500 m a 5:00/km.
        //    Sin interpolar daría 1650 (la muestra siguiente); interpolando, 1500.
        let coarse: [BestSplit.CurvePoint] = (0...22).map { (Double($0) * 150, Double($0) * 500) }
        assert(BestSplit.fastestWindow(coarse, meters: 5000) == 1500,
               "interpolación del final: \(BestSplit.fastestWindow(coarse, meters: 5000) ?? -1)")

        print("ok: los 5 checks de fastestWindow pasan")
    }
}
