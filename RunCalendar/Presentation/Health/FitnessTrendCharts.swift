import SwiftUI
import Charts

/// Gráficas de tendencia de condición: volumen semanal (barras), ritmo por corrida
/// (línea) y VO₂max en el tiempo (línea). Interactivas: toca para ver el valor.
struct FitnessTrendSection: View {
    let trend: FitnessTrend

    @State private var volumeSel: Date?
    @State private var paceSel: Date?
    @State private var vo2Sel: Date?

    private var enoughVolume: Bool { trend.weeklyVolume.count >= 2 }
    private var enoughPace: Bool { trend.pace.count >= 3 }
    private var enoughVO2: Bool { trend.vo2Max.count >= 2 }

    var body: some View {
        Section {
            if enoughVolume { volumeChart }
            if enoughPace { paceChart }
            if enoughVO2 { vo2Chart }
            if !enoughVolume && !enoughPace && !enoughVO2 {
                Label("Corre unas semanas más para ver tu tendencia aquí.",
                      systemImage: "chart.bar.xaxis")
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
        } header: {
            Text("Tu evolución")
        } footer: {
            Text("Toca cualquier punto para ver su valor. El VO₂max se mueve en meses: es la mejor "
                + "señal de que tu base aeróbica mejora.")
        }
    }

    // MARK: - Volumen semanal

    private var volumeChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Kilómetros por semana").font(.mSubheadline.weight(.semibold))
            Text("Cuánto corres cada semana. Subir de forma gradual construye tu base.")
                .font(.mCaption2).foregroundStyle(.secondary)

            Chart {
                ForEach(trend.weeklyVolume) { week in
                    BarMark(x: .value("Semana", week.weekStart, unit: .weekOfYear),
                            y: .value("km", week.km))
                        .foregroundStyle(Neon.accent)
                        .cornerRadius(3)
                }
                if let sel = nearestByDate(volumeSel, in: trend.weeklyVolume, \.weekStart) {
                    chartSelectionMark(date: sel.weekStart,
                                       title: sel.weekStart.mediumString(),
                                       value: "\(sel.km.formatted(.number.precision(.fractionLength(1)))) km")
                }
            }
            .chartXSelection(value: $volumeSel)
            .chartYAxisLabel("km")
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 150)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Ritmo por corrida

    private var paceChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ritmo por corrida").font(.mSubheadline.weight(.semibold))
            Text("Minutos por km en cada corrida. Más abajo = más rápido: si la línea baja, mejoras.")
                .font(.mCaption2).foregroundStyle(.secondary)

            Chart {
                ForEach(trend.pace) { point in
                    LineMark(x: .value("Fecha", point.date),
                             y: .value("Ritmo", point.paceSecondsPerKm))
                        .foregroundStyle(Neon.teal)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Fecha", point.date),
                              y: .value("Ritmo", point.paceSecondsPerKm))
                        .foregroundStyle(Neon.teal)
                        .symbolSize(30)
                }
                if let sel = nearestByDate(paceSel, in: trend.pace, \.date) {
                    chartSelectionMark(date: sel.date,
                                       title: sel.date.mediumString(),
                                       value: "\(paceText(sel.paceSecondsPerKm)) /km")
                }
            }
            .chartXSelection(value: $paceSel)
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    if let seconds = value.as(Int.self) {
                        AxisValueLabel { Text(paceText(seconds)) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { AxisValueLabel(format: .dateTime.day().month(.abbreviated)) }
            }
            .frame(height: 150)
        }
        .padding(.vertical, 4)
    }

    // MARK: - VO₂max en el tiempo

    private var vo2Chart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VO₂max").font(.mSubheadline.weight(.semibold))
            Text("Tu capacidad aeróbica (ml/kg·min). Cambia despacio; si sube en meses, tu condición mejora.")
                .font(.mCaption2).foregroundStyle(.secondary)

            Chart {
                ForEach(trend.vo2Max) { point in
                    LineMark(x: .value("Fecha", point.date),
                             y: .value("VO₂max", point.value))
                        .foregroundStyle(Neon.purple)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Fecha", point.date),
                              y: .value("VO₂max", point.value))
                        .foregroundStyle(Neon.purple)
                        .symbolSize(30)
                }
                if let sel = nearestByDate(vo2Sel, in: trend.vo2Max, \.date) {
                    chartSelectionMark(date: sel.date,
                                       title: sel.date.mediumString(),
                                       value: sel.value.formatted(.number.precision(.fractionLength(1))))
                }
            }
            .chartXSelection(value: $vo2Sel)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis {
                AxisMarks { AxisValueLabel(format: .dateTime.month(.abbreviated)) }
            }
            .frame(height: 150)
        }
        .padding(.vertical, 4)
    }

    private func paceText(_ secondsPerKm: Int) -> String {
        String(format: "%d:%02d", secondsPerKm / 60, secondsPerKm % 60)
    }
}
