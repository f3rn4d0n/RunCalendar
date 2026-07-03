import Foundation
import Observation

/// Coordina la preferencia de recordatorios y su reagendado a partir de las carreras.
@MainActor
@Observable
final class RemindersViewModel {

    private(set) var isEnabled: Bool
    var permissionDenied = false

    private let scheduler: ReminderScheduler
    private let racesViewModel: RacesViewModel
    private let trainingViewModel: TrainingViewModel
    private let defaults = UserDefaults.standard
    private let key = "remindersEnabled"

    init(scheduler: ReminderScheduler, racesViewModel: RacesViewModel, trainingViewModel: TrainingViewModel) {
        self.scheduler = scheduler
        self.racesViewModel = racesViewModel
        self.trainingViewModel = trainingViewModel
        self.isEnabled = defaults.bool(forKey: key)
    }

    /// Activa o desactiva los recordatorios. Al activar, pide permiso y agenda.
    func setEnabled(_ enabled: Bool) async {
        guard enabled else {
            persist(false)
            await scheduler.cancelAll()
            return
        }
        let granted = await scheduler.requestAuthorization()
        guard granted else {
            permissionDenied = true
            persist(false)
            return
        }
        permissionDenied = false
        persist(true)
        await scheduler.reschedule(races: racesViewModel.races, trainings: trainingViewModel.sessions)
    }

    /// Reagenda si los recordatorios están activos (p. ej. al cambiar las carreras).
    func refresh() async {
        guard isEnabled else { return }
        await scheduler.reschedule(races: racesViewModel.races, trainings: trainingViewModel.sessions)
    }

    private func persist(_ value: Bool) {
        isEnabled = value
        defaults.set(value, forKey: key)
    }
}
