import Foundation
import UserNotifications

/// Implementación de `ReminderScheduler` con notificaciones locales del sistema.
struct LocalNotificationService: ReminderScheduler {

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    func cancelAll() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func reschedule(races: [Race], trainings: [TrainingSession], preferences: ReminderPreferences) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let calendar = Calendar.current
        let now = Date()
        let used = await scheduleRaces(
            races, preferences: preferences, budget: Self.maxNotifications, calendar: calendar, now: now
        )
        if preferences.trainings {
            _ = await scheduleTrainings(
                trainings, budget: Self.maxNotifications - used, calendar: calendar, now: now
            )
        }
    }

    /// Agenda recordatorios de carrera y de kit según las preferencias. Devuelve cuántos agendó.
    private func scheduleRaces(
        _ races: [Race], preferences: ReminderPreferences, budget: Int, calendar: Calendar, now: Date
    ) async -> Int {
        let reminders = Self.raceReminders(from: preferences)
        let futureRaces = races.filter { $0.status == .upcoming && $0.date > now }
        let upcoming = futureRaces.sorted { $0.date < $1.date }
        var scheduled = 0
        for race in upcoming {
            for reminder in reminders {
                guard scheduled < budget,
                      let fireDate = triggerDate(daysBefore: reminder.daysBefore, hour: reminder.hour,
                                                 base: race.date, calendar: calendar),
                      fireDate > now else { continue }
                await add(
                    id: "race-\(race.id)-\(reminder.daysBefore)",
                    title: race.name,
                    body: "\(reminder.label) · \(race.discipline.displayName) en \(race.location.name)",
                    fireDate: fireDate,
                    calendar: calendar
                )
                scheduled += 1
            }
            if preferences.kit, let kitDate = race.kitPickup?.date, kitDate > now, scheduled < budget,
               let fireDate = triggerDate(daysBefore: 1, hour: preferences.reminderHour,
                                          base: kitDate, calendar: calendar),
               fireDate > now {
                await add(
                    id: "kit-\(race.id)",
                    title: "Entrega de kit — \(race.name)",
                    body: "Recoge tu kit: es mañana.",
                    fireDate: fireDate,
                    calendar: calendar
                )
                scheduled += 1
            }
        }
        return scheduled
    }

    /// Agenda un aviso a la hora de cada entrenamiento pendiente. Devuelve cuántos agendó.
    private func scheduleTrainings(
        _ trainings: [TrainingSession], budget: Int, calendar: Calendar, now: Date
    ) async -> Int {
        let futureTrainings = trainings.filter { !$0.completed && $0.date > now }
        let upcoming = futureTrainings.sorted { $0.date < $1.date }
        var scheduled = 0
        for training in upcoming {
            guard scheduled < budget else { break }
            await add(
                id: "training-\(training.id)",
                title: training.title,
                body: "Entrenamiento de \(training.type.displayName)",
                fireDate: training.date,
                calendar: calendar
            )
            scheduled += 1
        }
        return scheduled
    }

    // MARK: - Config

    private struct RaceReminder {
        let daysBefore: Int
        let hour: Int
        let label: String
    }

    private static let maxNotifications = 50 // margen bajo el límite de 64 de iOS

    /// Construye los avisos de carrera según las preferencias.
    private static func raceReminders(from prefs: ReminderPreferences) -> [RaceReminder] {
        var reminders: [RaceReminder] = []
        if prefs.leadDays > 1 {
            reminders.append(RaceReminder(daysBefore: prefs.leadDays, hour: prefs.reminderHour,
                                          label: "Faltan \(prefs.leadDays) días"))
        }
        if prefs.dayBefore {
            reminders.append(RaceReminder(daysBefore: 1, hour: prefs.reminderHour, label: "Es mañana"))
        }
        if prefs.dayOf {
            reminders.append(RaceReminder(daysBefore: 0, hour: prefs.reminderHour, label: "¡Hoy es el día!"))
        }
        return reminders
    }

    private func triggerDate(daysBefore: Int, hour: Int, base: Date, calendar: Calendar) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: base) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
    }

    private func add(id: String, title: String, body: String, fireDate: Date, calendar: Calendar) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
