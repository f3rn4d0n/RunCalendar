import Foundation
import Testing
@testable import RunCalendar

/// `LiftRecords` es el análogo de `PersonalRecords` (récords de carrera) para levantamiento: en
/// vez de rankear por ritmo, rankea por 1RM estimado (carga externa) o por repeticiones (peso
/// corporal). Por eso las pruebas son sobre todo de **propiedad**: la fórmula de Epley y el tope
/// de reps están sin calibrar, así que fijar números exactos cementaría una calibración que nadie
/// ha comprobado — igual criterio que `RecoveryTests`.
@Suite("LiftRecords · propiedades del ranking")
struct LiftRecordsTests {

    private func session(_ sets: [StrengthSet], completed: Bool = true, id: String = UUID().uuidString,
                        date: Date = Date()) -> TrainingSession {
        TrainingSession(id: id, date: date, type: .crossfit, title: "WOD \(id.prefix(4))",
                        sets: sets, completed: completed)
    }

    @Test("Con una sola repetición, el 1RM estimado es el peso tal cual")
    func singleRepIsExactlyTheWeight() {
        let sessions = [session([StrengthSet(exercise: .pressBanca, weightKg: 100, reps: 1)])]
        let record = LiftRecords.compute(sessions: sessions).first { $0.exercise == .pressBanca }
        #expect(record?.best.estimatedOneRM == 100)
    }

    @Test("Más peso con las mismas repeticiones nunca rankea peor")
    func moreWeightSameRepsNeverRanksLower() {
        let weights: [Double] = [60, 80, 100, 120]
        let oneRMs = weights.map { StrengthSet(exercise: .sentadilla, weightKg: $0, reps: 5).estimatedOneRM ?? 0 }
        for (lighter, heavier) in zip(oneRMs, oneRMs.dropFirst()) {
            #expect(heavier >= lighter, "más peso dio menos 1RM: \(oneRMs)")
        }
    }

    @Test("Más repeticiones con el mismo peso nunca rankea peor")
    func moreRepsSameWeightNeverRanksLower() {
        let oneRMs = [1, 3, 5, 8].map { StrengthSet(exercise: .sentadilla, weightKg: 100, reps: $0).estimatedOneRM ?? 0 }
        for (fewer, more) in zip(oneRMs, oneRMs.dropFirst()) {
            #expect(more >= fewer, "más reps dio menos 1RM: \(oneRMs)")
        }
    }

    @Test("Más repeticiones con menos peso puede ganarle a más peso con una sola rep")
    func moreRepsCanBeatMoreWeight() {
        // El corazón de la fase: sin esto, un ranking por peso bruto nunca dejaría que
        // 105 kg × 3 (Epley ≈ 115.5) le ganara a 110 kg × 1 (110).
        let heavySingle = StrengthSet(exercise: .sentadilla, weightKg: 110, reps: 1).estimatedOneRM ?? 0
        let lighterTriple = StrengthSet(exercise: .sentadilla, weightKg: 105, reps: 3).estimatedOneRM ?? 0
        #expect(lighterTriple > heavySingle)
    }

    @Test("El récord es siempre el máximo del historial")
    func bestIsTheMaxOfTheHistory() {
        let sessions = [
            session([StrengthSet(exercise: .pesoMuerto, weightKg: 100, reps: 5)],
                    date: Date().addingTimeInterval(-86400 * 14)),
            session([StrengthSet(exercise: .pesoMuerto, weightKg: 130, reps: 3)],
                    date: Date().addingTimeInterval(-86400 * 7)),
            session([StrengthSet(exercise: .pesoMuerto, weightKg: 110, reps: 4)])
        ]
        guard let record = LiftRecords.compute(sessions: sessions).first(where: { $0.exercise == .pesoMuerto }) else {
            Issue.record("se esperaba un récord de peso muerto")
            return
        }
        let maxInHistory = record.history.compactMap { $0.estimatedOneRM }.max()
        #expect(record.best.estimatedOneRM == maxInHistory)
    }

    @Test("Ejercicios distintos no se mezclan en el mismo récord")
    func exercisesDoNotMix() {
        let sessions = [session([
            StrengthSet(exercise: .sentadilla, weightKg: 140, reps: 3),
            StrengthSet(exercise: .pesoMuerto, weightKg: 100, reps: 3)
        ])]
        let records = LiftRecords.compute(sessions: sessions)
        #expect(records.contains { $0.exercise == .sentadilla })
        #expect(records.contains { $0.exercise == .pesoMuerto })
        #expect(records.first { $0.exercise == .sentadilla }?.history.count == 1)
    }

    @Test("Una sesión sin completar no produce récord")
    func incompleteSessionsDoNotCount() {
        let sessions = [session([StrengthSet(exercise: .sentadilla, weightKg: 999, reps: 1)], completed: false)]
        #expect(LiftRecords.compute(sessions: sessions).isEmpty)
    }

    @Test("Varias series del mismo ejercicio en una sesión cuentan como un esfuerzo, y el historial es cronológico")
    func historyHasOneEffortPerSessionChronological() {
        let oldSession = session([StrengthSet(exercise: .cargada, weightKg: 60, reps: 3)],
                                 date: Date().addingTimeInterval(-86400 * 30))
        let recentSession = session([
            StrengthSet(exercise: .cargada, weightKg: 70, reps: 3),   // calentamiento
            StrengthSet(exercise: .cargada, weightKg: 80, reps: 2)    // la buena
        ])
        let records = LiftRecords.compute(sessions: [oldSession, recentSession])
        guard let record = records.first(where: { $0.exercise == .cargada }) else {
            Issue.record("se esperaba un récord de cargada")
            return
        }
        #expect(record.history.count == 2, "una serie por sesión, no cinco")
        #expect(record.history.map(\.date) == record.history.map(\.date).sorted())
    }

    @Test("Una serie de más de 12 repeticiones no gana récord en carga externa, aunque su Epley crudo sea el mayor")
    func highRepSetsNeverSetARecordInExternalLifts() {
        let sessions = [
            session([StrengthSet(exercise: .sentadilla, weightKg: 60, reps: 20)]),   // Epley crudo: 100
            session([StrengthSet(exercise: .sentadilla, weightKg: 90, reps: 5)])     // Epley: 105
        ]
        let record = LiftRecords.compute(sessions: sessions).first { $0.exercise == .sentadilla }
        #expect(record?.history.count == 1, "la serie de 20 reps no debería contar")
        #expect(record?.best.weightKg == 90)
    }

    @Test("En peso corporal, más repeticiones gana; a igualdad de reps, gana el lastre")
    func bodyweightRanksByRepsThenLoad() {
        let sessions = [
            session([StrengthSet(exercise: .dominada, weightKg: 0, reps: 8)]),
            session([StrengthSet(exercise: .dominada, weightKg: 0, reps: 12)]),
            session([StrengthSet(exercise: .dominada, weightKg: 10, reps: 12)])
        ]
        guard let record = LiftRecords.compute(sessions: sessions).first(where: { $0.exercise == .dominada }) else {
            Issue.record("se esperaba un récord de dominada")
            return
        }
        #expect(record.best.reps == 12)
        #expect(record.best.weightKg == 10, "a 12 reps iguales, gana la que lleva lastre")
    }

    @Test("En peso corporal no hay 1RM estimado")
    func bodyweightHasNoOneRMEstimate() {
        #expect(StrengthSet(exercise: .dominada, weightKg: 5, reps: 8).estimatedOneRM == nil)
        #expect(StrengthSet(exercise: .fondo, weightKg: 0, reps: 15).estimatedOneRM == nil)
    }

    @Test("Una serie de más de 12 repeticiones sí cuenta en peso corporal")
    func highRepBodyweightStillCounts() {
        let sessions = [session([StrengthSet(exercise: .dominada, weightKg: 0, reps: 30)])]
        let record = LiftRecords.compute(sessions: sessions).first { $0.exercise == .dominada }
        #expect(record?.best.reps == 30)
    }

    @Test("Peso o repeticiones en cero no producen esfuerzo, sin crash")
    func zeroWeightOrRepsProducesNoEffort() {
        let sessions = [session([
            StrengthSet(exercise: .sentadilla, weightKg: 100, reps: 0),
            StrengthSet(exercise: .pressBanca, weightKg: 0, reps: 5)
        ])]
        let records = LiftRecords.compute(sessions: sessions)
        #expect(!records.contains { $0.exercise == .sentadilla }, "0 reps no es un esfuerzo")
        #expect(!records.contains { $0.exercise == .pressBanca }, "0 kg en carga externa no es un dato real")
    }

    @Test("Sin sesiones de fuerza, no hay récords")
    func noStrengthSessionsMeansNoRecords() {
        let onlyRunning = [TrainingSession(date: Date(), type: .running, title: "5K", distanceKm: 5, completed: true)]
        #expect(LiftRecords.compute(sessions: onlyRunning).isEmpty)
    }

    // MARK: - Fusión de las dos fuentes: WOD embebido + registro suelto

    @Test("Un registro suelto compite por récord contra una serie de WOD del mismo ejercicio")
    func looseEntryCompetesWithSessionSet() {
        let sessions = [session([StrengthSet(exercise: .pesoMuerto, weightKg: 100, reps: 5)])]
        let entries = [LiftEntry(exercise: .pesoMuerto, weightKg: 150, reps: 1,
                                 date: Date().addingTimeInterval(-3600))]
        let record = LiftRecords.compute(sessions: sessions, entries: entries)
            .first { $0.exercise == .pesoMuerto }
        #expect(record?.best.estimatedOneRM == 150, "el registro suelto es el mejor esfuerzo")
        #expect(record?.history.count == 2)
    }

    @Test("Y al revés: una serie de WOD puede ganarle a un registro suelto más flojo")
    func sessionSetCanBeatLooseEntry() {
        let sessions = [session([StrengthSet(exercise: .cargada, weightKg: 90, reps: 1)])]
        let entries = [LiftEntry(exercise: .cargada, weightKg: 60, reps: 3,
                                 date: Date().addingTimeInterval(-3600))]
        let record = LiftRecords.compute(sessions: sessions, entries: entries)
            .first { $0.exercise == .cargada }
        #expect(record?.best.weightKg == 90)
    }

    @Test("history(for:) incluye una serie de más de 12 reps que compute() excluiría del récord")
    func historyIncludesHighRepSets() {
        let sessions = [session([StrengthSet(exercise: .sentadilla, weightKg: 60, reps: 20)])]
        let history = LiftRecords.history(for: .sentadilla, sessions: sessions)
        #expect(history.count == 1, "el historial sí lo muestra, aunque no compita por récord")
        #expect(LiftRecords.compute(sessions: sessions).isEmpty, "compute() lo sigue excluyendo")
    }

    @Test("history(for:) de un ejercicio sin ningún esfuerzo es vacío")
    func historyIsEmptyWithoutEfforts() {
        let sessions = [session([StrengthSet(exercise: .sentadilla, weightKg: 100, reps: 5)])]
        #expect(LiftRecords.history(for: .pressBanca, sessions: sessions).isEmpty)
    }
}

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

/// `WeightliftingViewModel`: el CRUD de registros sueltos y la edición puntual de un esfuerzo
/// —sin importar si vino de un WOD o de un registro suelto— pasan por aquí.
@Suite("WeightliftingViewModel · registro suelto y edición")
@MainActor
struct WeightliftingViewModelTests {

    @Test("Agregar un registro lo manda al repo de entries")
    func addSendsToRepo() async {
        let app = TestApp()
        await app.start()

        _ = await app.weightlifting.save(
            LiftEntry(exercise: .sentadilla, weightKg: 100, reps: 5), isNew: true)

        #expect(app.liftEntryRepo.added.count == 1)
        #expect(app.liftEntryRepo.added.first?.exercise == .sentadilla)
    }

    @Test("Borrar un registro lo manda al repo de entries")
    func deleteSendsToRepo() async {
        let entry = LiftEntry(exercise: .sentadilla, weightKg: 100, reps: 5)
        let app = TestApp(liftEntries: [entry])
        await app.start()

        await app.weightlifting.delete(entry)

        #expect(app.liftEntryRepo.deleted == [entry.id])
    }

    @Test("Editar un esfuerzo suelto actualiza el LiftEntry en su repo")
    func editingLooseEffortUpdatesEntry() async {
        let entry = LiftEntry(exercise: .sentadilla, weightKg: 100, reps: 5)
        let app = TestApp(liftEntries: [entry])
        await app.start()

        let effort = app.weightlifting.history(for: .sentadilla).first { $0.origin.isEntry }
        guard let effort else { Issue.record("se esperaba un esfuerzo suelto"); return }

        let ok = await app.weightlifting.updatePerformance(of: effort, weightKg: 110, reps: 3)

        #expect(ok)
        #expect(app.liftEntryRepo.updated.last?.weightKg == 110)
        #expect(app.liftEntryRepo.updated.last?.reps == 3)
    }

    @Test("Editar un esfuerzo de WOD actualiza esa serie dentro de la sesión, no un LiftEntry")
    func editingSessionEffortUpdatesTrainingSession() async {
        let session = TrainingSession(date: Date(), type: .crossfit, title: "WOD",
                                      sets: [StrengthSet(exercise: .cargada, weightKg: 70, reps: 3)],
                                      completed: true)
        let app = TestApp(sessions: [session])
        await app.start()

        let effort = app.weightlifting.history(for: .cargada).first
        guard let effort else { Issue.record("se esperaba un esfuerzo de WOD"); return }

        let ok = await app.weightlifting.updatePerformance(of: effort, weightKg: 80, reps: 2)

        #expect(ok)
        #expect(app.liftEntryRepo.updated.isEmpty, "no debe tocar el repo de entries")
        #expect(app.trainingRepo.updated.last?.sets.first?.weightKg == 80)
        #expect(app.trainingRepo.updated.last?.sets.first?.reps == 2)
    }
}

private extension LiftEffort.Origin {
    var isEntry: Bool { if case .entry = self { return true }; return false }
}
