import Foundation
import Testing
@testable import RunCalendar

/// Persistencia de `StrengthSet`: el mismo patrón que `Goal.manualMissions` (array embebido en el
/// documento de la sesión), verificado en las dos capas que importan — el DTO y el paso por el VM.
@Suite("Fuerza · registro")
@MainActor
struct StrengthRegistrationTests {

    private func session(sets: [StrengthSet] = []) -> TrainingSession {
        TrainingSession(date: Date(), type: .crossfit, title: "WOD", sets: sets)
    }

    @Test("Guardar una sesión manda las series al repo, intactas")
    func savingSessionSendsSetsToRepo() async {
        let sets = [
            StrengthSet(exercise: .sentadilla, weightKg: 100, reps: 5),
            StrengthSet(exercise: .pesoMuerto, weightKg: 120, reps: 3)
        ]
        let app = TestApp(sessions: [session()])
        await app.start()

        _ = await app.training.save(session(sets: sets), isNew: false)

        let saved = app.trainingRepo.updated.last
        #expect(saved?.sets.count == 2)
        #expect(saved?.sets.map(\.exercise) == [.sentadilla, .pesoMuerto])
        #expect(saved?.sets.map(\.weightKg) == [100, 120])
    }

    @Test("El DTO conserva las series completas de ida y vuelta")
    func dtoRoundTripKeepsSets() {
        let original = session(sets: [
            StrengthSet(exercise: .dominada, weightKg: 5, reps: 8),
            StrengthSet(exercise: .pressBanca, weightKg: 80, reps: 1)
        ])
        let dict = TrainingDTO.toFirestore(original)
        let restored = TrainingDTO.toDomain(id: original.id, data: dict)

        #expect(restored?.sets.count == 2)
        #expect(restored?.sets.map(\.id) == original.sets.map(\.id))
        #expect(restored?.sets.map(\.exercise) == [.dominada, .pressBanca])
        #expect(restored?.sets.map(\.weightKg) == [5, 80])
        #expect(restored?.sets.map(\.reps) == [8, 1])
    }

    @Test("Sin series, el DTO escribe un arreglo vacío, no nil")
    func dtoWritesEmptyArrayNotNil() {
        // Con `setData(merge: true)` un arreglo se reemplaza entero, pero solo si la clave viaja.
        // Si esto escribiera `nil` en vez de `[]`, borrar la última serie no se borraría nunca.
        let dict = TrainingDTO.toFirestore(session())
        #expect((dict["sets"] as? [[String: Any]])?.isEmpty == true)
    }

    @Test("Un ejercicio desconocido se descarta sin tumbar las demás series")
    func dtoDropsUnknownExercise() {
        var dict = TrainingDTO.toFirestore(session(sets: [
            StrengthSet(exercise: .sentadilla, weightKg: 100, reps: 5)
        ]))
        var sets = dict["sets"] as? [[String: Any]] ?? []
        sets.append(["id": UUID().uuidString, "exercise": "Zancada lunar", "weightKg": 40, "reps": 10])
        dict["sets"] = sets

        let restored = TrainingDTO.toDomain(id: UUID().uuidString, data: dict)
        #expect(restored?.sets.count == 1)
        #expect(restored?.sets.first?.exercise == .sentadilla)
    }

    @Test("El volumen total es la suma de las series; nil sin ninguna")
    func strengthVolumeIsTheSumOfSets() {
        let withSets = session(sets: [
            StrengthSet(exercise: .sentadilla, weightKg: 100, reps: 5),   // 500
            StrengthSet(exercise: .pesoMuerto, weightKg: 120, reps: 3)    // 360
        ])
        #expect(withSets.strengthVolumeKg == 860)
        #expect(session().strengthVolumeKg == nil)
    }
}
