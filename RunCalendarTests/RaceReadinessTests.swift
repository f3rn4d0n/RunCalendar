import Testing
@testable import RunCalendar

/// `RaceReadiness.timing`: el consejo cambia según las semanas que faltan. Subir la tirada larga
/// a +1–2 km/semana toma tiempo; si no alcanza, la app deja de pedirlo.
@Suite("RaceReadiness · semanas que faltan")
struct RaceReadinessTests {

    @Test("Sin fecha de referencia no hay dimensión de tiempo")
    func noDeadlineNoTiming() {
        #expect(RaceReadiness.timing(gapKm: 8, weeksAvailable: nil) == nil)
    }

    @Test("Sin brecha no hay nada que planear")
    func noGapNoPlan() {
        #expect(RaceReadiness.timing(gapKm: 0, weeksAvailable: 6) == nil)
        #expect(RaceReadiness.timing(gapKm: -3, weeksAvailable: 6) == nil)
    }

    @Test("8 km de brecha con 6 semanas: alcanza (la última es afinamiento)")
    func enoughTime() {
        let timing = RaceReadiness.timing(gapKm: 8, weeksAvailable: 6)
        #expect(timing?.needed == 4)
        #expect(timing?.usable == 5)
        #expect((timing?.needed ?? 99) <= (timing?.usable ?? 0))
    }

    @Test("Con 1 semana no quedan semanas útiles: toca mantener, no intentarlo")
    func noUsableWeeks() {
        #expect(RaceReadiness.timing(gapKm: 8, weeksAvailable: 1)?.usable == 0)
    }

    @Test("Justo en el límite todavía alcanza")
    func exactlyEnough() {
        let timing = RaceReadiness.timing(gapKm: 4, weeksAvailable: 3)
        #expect(timing?.needed == 2)
        #expect(timing?.usable == 2)
    }

    @Test("Las semanas necesarias redondean hacia arriba")
    func roundsUp() {
        // 5 km no son 2.5 semanas, son 3.
        #expect(RaceReadiness.timing(gapKm: 5, weeksAvailable: 10)?.needed == 3)
    }
}
