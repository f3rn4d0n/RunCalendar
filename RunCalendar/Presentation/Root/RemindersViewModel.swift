import Foundation
import Observation

/// Coordina la preferencia de recordatorios y su reagendado a partir de las carreras y entrenamientos.
@MainActor
@Observable
final class RemindersViewModel {

    private(set) var isEnabled: Bool
    private(set) var preferences: ReminderPreferences
    var permissionDenied = false

    private let scheduler: ReminderScheduler
    private let racesViewModel: RacesViewModel
    private let trainingViewModel: TrainingViewModel

    private static let enabledKey = "remindersEnabled"
    private static let prefsKey = "reminderPreferences"

    init(scheduler: ReminderScheduler, racesViewModel: RacesViewModel, trainingViewModel: TrainingViewModel) {
        self.scheduler = scheduler
        self.racesViewModel = racesViewModel
        self.trainingViewModel = trainingViewModel

        let defaults = UserDefaults.standard
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        if let data = defaults.data(forKey: Self.prefsKey),
           let decoded = try? JSONDecoder().decode(ReminderPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = .default
        }
    }

    /// Activa o desactiva los recordatorios. Al activar, pide permiso y agenda.
    func setEnabled(_ enabled: Bool) async {
        guard enabled else {
            setStoredEnabled(false)
            await scheduler.cancelAll()
            return
        }
        let granted = await scheduler.requestAuthorization()
        guard granted else {
            permissionDenied = true
            setStoredEnabled(false)
            return
        }
        permissionDenied = false
        setStoredEnabled(true)
        await reschedule()
    }

    /// Guarda nuevas preferencias y reagenda.
    func updatePreferences(_ preferences: ReminderPreferences) async {
        self.preferences = preferences
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: Self.prefsKey)
        }
        await reschedule()
    }

    /// Reagenda si los recordatorios están activos (p. ej. al cambiar carreras o entrenamientos).
    func refresh() async {
        await reschedule()
    }

    private func reschedule() async {
        guard isEnabled else { return }
        await scheduler.reschedule(
            races: racesViewModel.races,
            trainings: trainingViewModel.sessions,
            preferences: preferences
        )
    }

    private func setStoredEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: Self.enabledKey)
    }
}
