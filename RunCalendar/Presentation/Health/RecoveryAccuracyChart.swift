import SwiftUI
import Charts

/// Compara cómo te sentiste (check-in) con lo que el modelo estimó, en escala 1–5.
/// Es la antesala de la calibración: muestra si el modelo acierta o tiene sesgo.
struct RecoveryAccuracyChart: View {
    /// Check-ins cronológicos (se muestran los más recientes).
    let checkIns: [RecoveryCheckIn]

    @State private var selection: Date?

    private let feltSeries = "Cómo te sentiste"
    private let modelSeries = "Modelo estimó"

    /// Últimos ~21 registros para no saturar.
    private var data: [RecoveryCheckIn] { Array(checkIns.suffix(21)) }

    var body: some View {
        Section {
            Text(verdict).font(.mCaption).foregroundStyle(.secondary)

            Chart {
                ForEach(data) { checkIn in
                    LineMark(x: .value("Día", checkIn.date, unit: .day),
                             y: .value("Nivel", checkIn.feeling))
                        .foregroundStyle(by: .value("Serie", feltSeries))
                        .symbol(by: .value("Serie", feltSeries))
                    LineMark(x: .value("Día", checkIn.date, unit: .day),
                             y: .value("Nivel", checkIn.modelFeeling))
                        .foregroundStyle(by: .value("Serie", modelSeries))
                        .symbol(by: .value("Serie", modelSeries))
                }
                if let picked = nearestByDate(selection, in: data, \.date) {
                    chartSelectionMark(date: picked.date, title: picked.date.mediumString(),
                                       value: "Tú \(picked.feeling) · modelo \(picked.modelFeeling)")
                }
            }
            .chartForegroundStyleScale([feltSeries: Neon.accent, modelSeries: Neon.orange])
            .chartXSelection(value: $selection)
            .chartYScale(domain: 1...5)
            .chartYAxis {
                AxisMarks(values: [1, 3, 5]) { value in
                    AxisGridLine()
                    if let level = value.as(Int.self) {
                        AxisValueLabel { Text(levelLabel(level)) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { AxisValueLabel(format: .dateTime.day().month(.abbreviated)) }
            }
            .frame(height: 160)
        } header: {
            Text("¿Acierta el modelo?")
        } footer: {
            Text("Compara tu sensación con lo que el estimado predijo. Con ~3–4 semanas de registros "
                + "se podrá personalizar la heurística a tu cuerpo.")
        }
    }

    /// Verdicto a partir del sesgo promedio (sentido − modelo).
    private var verdict: String {
        let diffs = data.map { $0.feeling - $0.modelFeeling }
        guard !diffs.isEmpty else { return "" }
        let avg = Double(diffs.reduce(0, +)) / Double(diffs.count)
        switch avg {
        case 0.5...:   return "Sueles sentirte mejor de lo que el modelo estima (tiende a ser pesimista)."
        case ..<(-0.5): return "Sueles sentirte peor de lo que el modelo estima (tiende a ser optimista)."
        default:       return "El modelo va bastante alineado con cómo te sientes."
        }
    }

    private func levelLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Agotado"
        case 3: return "Normal"
        default: return "Fresco"
        }
    }
}
