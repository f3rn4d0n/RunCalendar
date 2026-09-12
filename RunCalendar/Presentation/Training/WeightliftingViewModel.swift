import Foundation
import Observation

/// Registro suelto de levantamiento (sin WOD) + récords fusionados con las series embebidas en
/// sesiones de CrossFit (`trainingViewModel.sessions`). Un PR es un PR sin importar de dónde vino.
@MainActor
@Observable
final class WeightliftingViewModel {

    private(set) var entries: [LiftEntry] = []
    var errorMessage: String?
    private var hasStarted = false

    let userID: String
    private let observeEntries: ObserveLiftEntriesUseCase
    private let addEntry: AddLiftEntryUseCase
    private let updateEntry: UpdateLiftEntryUseCase
    private let deleteEntry: DeleteLiftEntryUseCase
    /// Para leer las series embebidas en WODs completos — récords e historial son de las dos
    /// fuentes juntas.
    private let trainingViewModel: TrainingViewModel

    init(
        userID: String,
        observeEntries: ObserveLiftEntriesUseCase,
        addEntry: AddLiftEntryUseCase,
        updateEntry: UpdateLiftEntryUseCase,
        deleteEntry: DeleteLiftEntryUseCase,
        trainingViewModel: TrainingViewModel
    ) {
        self.userID = userID
        self.observeEntries = observeEntries
        self.addEntry = addEntry
        self.updateEntry = updateEntry
        self.deleteEntry = deleteEntry
        self.trainingViewModel = trainingViewModel
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        for await items in observeEntries(userID: userID) {
            entries = items
        }
    }

    /// Récords de todos los ejercicios con al menos un esfuerzo, fusionando WODs + registros sueltos.
    var records: [LiftRecord] {
        LiftRecords.compute(sessions: trainingViewModel.sessions, entries: entries)
    }

    /// Historial completo de un ejercicio (sin el tope de reps del récord), para el detalle.
    func history(for exercise: StrengthExercise) -> [LiftEffort] {
        LiftRecords.history(for: exercise, sessions: trainingViewModel.sessions, entries: entries)
    }

    func save(_ entry: LiftEntry, isNew: Bool) async -> Bool {
        do {
            if isNew { try await addEntry(entry, userID: userID) }
            else { try await updateEntry(entry, userID: userID) }
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ entry: LiftEntry) async {
        do { try await deleteEntry(entryID: entry.id, userID: userID) }
        catch { errorMessage = error.localizedDescription }
    }

    /// Edita el peso/reps de un esfuerzo puntual sin importar de dónde vino: si es un registro
    /// suelto, actualiza el `LiftEntry`; si viene de un WOD, muta esa serie dentro de la sesión
    /// dueña y la guarda a través de `trainingViewModel` (misma puerta que usa el formulario).
    func updatePerformance(of effort: LiftEffort, weightKg: Double, reps: Int) async -> Bool {
        switch effort.origin {
        case .entry(let entryID):
            guard var entry = entries.first(where: { $0.id == entryID }) else { return false }
            entry.weightKg = weightKg
            entry.reps = reps
            return await save(entry, isNew: false)
        case .session(let sessionID, let setID):
            guard var session = trainingViewModel.sessions.first(where: { $0.id == sessionID }),
                  let idx = session.sets.firstIndex(where: { $0.id == setID })
            else { return false }
            session.sets[idx].weightKg = weightKg
            session.sets[idx].reps = reps
            return await trainingViewModel.save(session, isNew: false)
        }
    }
}
