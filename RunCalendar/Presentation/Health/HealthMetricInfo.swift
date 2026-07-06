import Foundation

/// Contenido educativo de una métrica: importancia, referencias y valoración del dato del usuario.
struct MetricInfo {
    let importance: String
    let reference: [String]
    /// Valoración dinámica del valor real del usuario (nil si no aplica).
    let assessment: String?
}

/// Construye el contenido educativo de cada métrica de condición.
enum HealthMetricInfo {

    static func thisWeek() -> MetricInfo {
        MetricInfo(
            importance: "Refleja tu carga de entrenamiento reciente. Aumentar el volumen de forma "
                + "gradual (no más de ~10% por semana) construye resistencia y reduce el riesgo de lesión.",
            reference: ["Compáralo con tu promedio: si es mucho mayor, cuida la recuperación."],
            assessment: nil
        )
    }

    static func weeklyAverage(weeks: Int) -> MetricInfo {
        MetricInfo(
            importance: "Promedio de km por semana en las últimas \(weeks) semanas. Mide tu "
                + "consistencia, que es lo que más construye tu base aeróbica. Un volumen sostenido "
                + "importa más que una sola semana fuerte.",
            reference: [
                "Base para 5k–10k: ~15–25 km/sem.",
                "Medio maratón: ~30–40 km/sem.",
                "Maratón: ~50+ km/sem."
            ],
            assessment: nil
        )
    }

    static func longestRun() -> MetricInfo {
        MetricInfo(
            importance: "Tu tirada más larga indica hasta qué distancia puedes rendir. Para una "
                + "carrera, tu long run debe acercarse a (o cubrir) la distancia objetivo; en maratón "
                + "se suele llegar a ~32 km, no a los 42.",
            reference: [
                "5k → ~5 km · 10k → ~10 km",
                "21k → ~18 km · 42k → ~32 km"
            ],
            assessment: nil
        )
    }

    static func runCount() -> MetricInfo {
        MetricInfo(
            importance: "Cuántas veces corriste en la ventana. La frecuencia regular progresa más "
                + "que sesiones aisladas, siempre dejando días de recuperación.",
            reference: ["Frecuencia típica para progresar: 3–5 días por semana."],
            assessment: nil
        )
    }

    static func restingHeartRate(_ value: Double) -> MetricInfo {
        let bpm = Int(value.rounded())
        let category: String
        switch bpm {
        case ..<50: category = "Excelente — típico de personas muy entrenadas."
        case 50..<60: category = "Muy bueno."
        case 60..<70: category = "Bueno."
        case 70..<80: category = "Promedio."
        case 80...100: category = "Alto dentro de lo normal; hay margen con más base aeróbica."
        default: category = "Elevado — si se mantiene así, conviene consultarlo con un médico."
        }
        return MetricInfo(
            importance: "Es tu pulso en reposo. Un corazón más eficiente bombea más sangre por latido, "
                + "así que suele bajar conforme mejora tu condición. También avisa fatiga: si sube "
                + "varios días seguidos, quizá necesitas descanso.",
            reference: [
                "Rango normal en adultos: 60–100 lpm.",
                "Deportistas de resistencia: 40–60 lpm.",
                "Más bajo (dentro de lo sano) suele indicar mejor condición."
            ],
            assessment: "Tu valor: \(bpm) lpm → \(category)"
        )
    }

    static func vo2Max(_ value: Double, age: Int?) -> MetricInfo {
        // Los umbrales bajan con la edad (aprox. tras los 30).
        let ageAdj = Double(max(0, (age ?? 30) - 30)) * 0.3
        let average = 35 - ageAdj
        let good = 43 - ageAdj
        let excellent = 50 - ageAdj
        let category: String
        switch value {
        case excellent...: category = "Excelente para tu edad."
        case good..<excellent: category = "Bueno."
        case average..<good: category = "Promedio."
        default: category = "Por debajo del promedio — mejora con base aeróbica (zona 2) constante."
        }
        let valueText = value.formatted(.number.precision(.fractionLength(1)))
        let assessment = age.map { "Tu valor: \(valueText) a los \($0) años → \(category)" }
            ?? "Tu valor: \(valueText) → \(category)"
        return MetricInfo(
            importance: "El VO₂max es el mejor indicador de tu condición aeróbica: cuánto oxígeno "
                + "aprovecha tu cuerpo al máximo esfuerzo. A mayor VO₂max, más capacidad para sostener "
                + "ritmos altos. Mejora con tiradas largas en zona 2 e intervalos.",
            reference: [
                "Referencia adulto: <35 bajo · 35–42 promedio · 43–49 bueno · 50+ excelente.",
                "Baja ~1 punto por década tras los 30 y varía por sexo."
            ],
            assessment: assessment
        )
    }
}
