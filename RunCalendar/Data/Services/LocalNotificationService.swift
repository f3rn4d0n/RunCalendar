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
        var used = await scheduleRaces(
            races, preferences: preferences, budget: Self.maxNotifications, calendar: calendar, now: now
        )
        if preferences.trainings {
            used += await scheduleTrainings(
                trainings, budget: Self.maxNotifications - used, calendar: calendar, now: now
            )
            _ = await scheduleOverdueTrainingNudge(
                trainings, hour: preferences.reminderHour,
                budget: Self.maxNotifications - used, calendar: calendar, now: now
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
            if preferences.kit, let kitDate = race.kitPickup?.date {
                for kit in Self.kitReminders(race: race, kitDate: kitDate, prefs: preferences,
                                             calendar: calendar, now: now) {
                    guard scheduled < budget else { break }
                    await add(id: kit.id, title: "Entrega de kit — \(race.name)",
                              body: kit.body, fireDate: kit.fireDate, calendar: calendar)
                    scheduled += 1
                }
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
                body: "Es hora: arranca tu \(training.type.displayName).",
                fireDate: training.date,
                calendar: calendar
            )
            scheduled += 1
        }
        return scheduled
    }

    /// Un único aviso de entrenamientos programados que ya pasaron y siguen sin completar
    /// (últimos 14 días), para que te pongas al día. Se dispara al próximo `reminderHour`.
    private func scheduleOverdueTrainingNudge(
        _ trainings: [TrainingSession], hour: Int, budget: Int, calendar: Calendar, now: Date
    ) async -> Int {
        guard budget > 0 else { return 0 }
        let cutoff = calendar.date(byAdding: .day, value: -14, to: now) ?? .distantPast
        let overdue = trainings.filter { !$0.completed && $0.date <= now && $0.date >= cutoff }
        guard !overdue.isEmpty, let fireDate = nextTime(hour: hour, calendar: calendar, now: now) else { return 0 }
        let body = overdue.count == 1
            ? "Tienes 1 entrenamiento pendiente por hacer: \(overdue[0].title)."
            : "Tienes \(overdue.count) entrenamientos pendientes por hacer. ¡Ponte al día!"
        await add(id: "training-overdue", title: "Entrenamientos pendientes",
                  body: body, fireDate: fireDate, calendar: calendar)
        return 1
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

    /// Próxima ocurrencia de `hour:00` (hoy si aún no pasa, si no mañana).
    private func nextTime(hour: Int, calendar: Calendar, now: Date) -> Date? {
        if let today = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now), today > now {
            return today
        }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow)
    }

    /// Avisos de kit (víspera y día mismo), con lugar y hora cuando existen.
    private static func kitReminders(
        race: Race, kitDate: Date, prefs: ReminderPreferences, calendar: Calendar, now: Date
    ) -> [(id: String, body: String, fireDate: Date)] {
        let time = calendar.dateComponents([.hour, .minute], from: kitDate)
        let hasTime = (time.hour ?? 0) != 0 || (time.minute ?? 0) != 0
        let timeStr = hasTime ? " a las \(timeFormatter.string(from: kitDate))" : ""
        let placeStr = (race.kitPickup?.location?.name).map { " en \($0)" } ?? ""

        var out: [(id: String, body: String, fireDate: Date)] = []
        // Víspera, a la hora de recordatorio.
        if let day = calendar.date(byAdding: .day, value: -1, to: kitDate),
           let fire = calendar.date(bySettingHour: prefs.reminderHour, minute: 0, second: 0, of: day),
           fire > now {
            out.append((id: "kit-\(race.id)-before",
                        body: "Recoge tu kit\(placeStr): mañana\(timeStr).", fireDate: fire))
        }
        // Día mismo: a la hora del kit si la tiene, si no a la hora de recordatorio.
        let dayOf = hasTime
            ? kitDate
            : calendar.date(bySettingHour: prefs.reminderHour, minute: 0, second: 0, of: kitDate)
        if let fire = dayOf, fire > now {
            out.append((id: "kit-\(race.id)-dayof",
                        body: "Hoy recoges tu kit\(placeStr)\(timeStr).", fireDate: fire))
        }
        return out
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        f.locale = .current
        return f
    }()

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
