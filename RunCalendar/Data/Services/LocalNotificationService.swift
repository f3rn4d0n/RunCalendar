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

    func reschedule(races: [Race]) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        let now = Date()
        let futureRaces = races.filter { $0.status == .upcoming && $0.date > now }
        let upcoming = futureRaces.sorted { $0.date < $1.date }

        var scheduled = 0
        for race in upcoming {
            for reminder in Self.raceReminders {
                guard scheduled < Self.maxNotifications,
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

            if let kitDate = race.kitPickup?.date, kitDate > now, scheduled < Self.maxNotifications,
               let fireDate = triggerDate(daysBefore: 1, hour: 18, base: kitDate, calendar: calendar),
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
    }

    // MARK: - Config

    private struct RaceReminder {
        let daysBefore: Int
        let hour: Int
        let label: String
    }

    private static let maxNotifications = 50 // margen bajo el límite de 64 de iOS
    private static let raceReminders: [RaceReminder] = [
        RaceReminder(daysBefore: 7, hour: 9, label: "Faltan 7 días"),
        RaceReminder(daysBefore: 1, hour: 18, label: "Es mañana"),
        RaceReminder(daysBefore: 0, hour: 7, label: "¡Hoy es el día!")
    ]

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
