// Check de RaceReadiness.timing. Compila contra los archivos reales (no duplica la lógica) y
// no necesita simulador ni target de tests. Desde la raíz del repo:
//
//   swiftc RunCalendar/Domain/Entities/RaceReadiness.swift RunCalendar/Domain/Entities/Race.swift \
//     Scripts/check-readiness-timing.swift -module-name check -o /tmp/check-readiness-timing \
//     && /tmp/check-readiness-timing
//
// Sin -O a propósito: en release los `assert` se compilan fuera y el check no verificaría nada.

@main struct CheckReadinessTiming {
    static func main() {
        // 1) Sin fecha de referencia (sección "¿Listo para…?") => sin dimensión de tiempo.
        assert(RaceReadiness.timing(gapKm: 8, weeksAvailable: nil) == nil, "sin fecha")

        // 2) Sin brecha (ya cubres la distancia) => nada que planear.
        assert(RaceReadiness.timing(gapKm: 0, weeksAvailable: 6) == nil, "sin brecha")
        assert(RaceReadiness.timing(gapKm: -3, weeksAvailable: 6) == nil, "long run de sobra")

        // 3) El caso del ejemplo: 8 km de brecha a +2 km/semana pide 4 semanas.
        //    Con 6 semanas quedan 5 útiles (la última es afinamiento) => alcanza.
        let sixWeeks = RaceReadiness.timing(gapKm: 8, weeksAvailable: 6)
        assert(sixWeeks?.needed == 4 && sixWeeks?.usable == 5, "6 semanas: \(sixWeeks as Any)")
        assert(sixWeeks!.needed <= sixWeeks!.usable, "con 6 semanas debe alcanzar")

        // 4) Misma brecha con 1 semana: 0 útiles => ni subir ni intentarlo, toca mantener.
        let oneWeek = RaceReadiness.timing(gapKm: 8, weeksAvailable: 1)
        assert(oneWeek?.usable == 0, "1 semana: \(oneWeek as Any)")

        // 5) Justo en el límite: 4 km de brecha pide 2 semanas; con 3 disponibles quedan 2 útiles.
        let tight = RaceReadiness.timing(gapKm: 4, weeksAvailable: 3)
        assert(tight?.needed == 2 && tight?.usable == 2, "límite: \(tight as Any)")
        assert(tight!.needed <= tight!.usable, "en el límite debe alcanzar")

        // 6) Redondea hacia arriba: 5 km no son 2.5 semanas, son 3.
        assert(RaceReadiness.timing(gapKm: 5, weeksAvailable: 10)?.needed == 3, "redondeo")

        print("ok: los 8 checks de RaceReadiness.timing pasan")
    }
}
