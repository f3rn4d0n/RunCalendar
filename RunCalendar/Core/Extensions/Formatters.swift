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
