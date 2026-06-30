import Foundation

extension Date {
    /// Fecha legible, p. ej. "dom 12 oct 2025".
    func mediumString() -> String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }

    /// Fecha con hora, p. ej. "12 oct 2025, 7:00".
    func dateTimeString() -> String {
        formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }
}

extension Decimal {
    /// Formatea un costo con su código de moneda.
    func currencyString(code: String) -> String {
        let number = NSDecimalNumber(decimal: self)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: number) ?? "\(self) \(code)"
    }
}

extension Int {
    /// Formatea una duración en segundos como tiempo, p. ej. 5025 → "1:23:45".
    func durationString() -> String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
