import Foundation

/// Check-in del review dominical: lo que **Salud no guarda**. El peso y la cintura del review
/// viven en HealthKit (ver `BodyMeasure`); aquí solo lo subjetivo. Fase 2 de la visión.
struct BodyLog: Identifiable, Equatable, Sendable {
    /// Día del registro (a medianoche); un review por día.
    let date: Date
    /// Nivel de energía de la semana, 1 (arrastrándote) a 5 (con pila).
    let energy: Int
    /// Nivel de hambre de la semana, 1 (sin apetito) a 5 (con hambre constante).
    let hunger: Int
    let notes: String

    var id: Date { date }

    init(date: Date = Date(), energy: Int, hunger: Int, notes: String = "") {
        self.date = Calendar.current.startOfDay(for: date)
        self.energy = energy
        self.hunger = hunger
        self.notes = notes
    }

    /// Etiqueta de la escala 1–5 de energía.
    static func energyLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Agotado"
        case 2: return "Bajo"
        case 3: return "Normal"
        case 4: return "Bien"
        default: return "Con pila"
        }
    }

    /// Etiqueta de la escala 1–5 de hambre.
    static func hungerLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Sin apetito"
        case 2: return "Poca"
        case 3: return "Normal"
        case 4: return "Alta"
        default: return "Constante"
        }
    }
}
