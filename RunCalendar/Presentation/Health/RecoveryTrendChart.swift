import SwiftUI
import Charts

/// Tendencia de recuperación de los últimos días: HRV (con su base y los días de
/// entrenamiento) y sueño por noche. Dos gráficas de una sola serie cada una, con
/// texto explicativo para que cualquier usuario las entienda.
struct RecoveryTrendSection: View {
    let trend: RecoveryTrend

    private var enoughHRV: Bool { trend.hrvValues.count >= 3 }
    private var enoughSleep: Bool { trend.sleepValues.count >= 3 }

    var body: some View {
        Section {
            if let assessment = trend.assessment {
                verdictBanner(assessment)
            }
            if enoughHRV {
                hrvChart
            }
            if enoughSleep {
                sleepChart
            }
            if !enoughHRV && !enoughSleep {
                Label("Aún no hay suficientes datos. Usa tu Apple Watch varias noches para ver tu tendencia.",
                      systemImage: "chart.line.uptrend.xyaxis")
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
        } header: {
            Text("Tu tendencia (últimos 30 días)")
        } footer: {
            Text("Lo que importa es tu tendencia comparada con tu propia base, no el valor de un solo día. "
                + "Un dato aislado varía por estrés, alcohol o una mala noche.")
        }
    }

    // MARK: - Veredicto

    private func verdictBanner(_ a: RecoveryTrendAssessment) -> some View {
        let color = verdictColor(a.verdict)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: a.verdict.systemImage)
                .font(.mTitle3)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(a.headline).font(.mHeadline)
                    Text("\(a.deviationPct >= 0 ? "+" : "")\(Int(a.deviationPct))% vs base")
                        .font(.mCaption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(color.opacity(0.15), in: Capsule())
                        .foregroundStyle(color)
                }
                Text(a.message).font(.mSubheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func verdictColor(_ verdict: TrendVerdict) -> Color {
        switch verdict {
        case .onTrack:      return Neon.green
        case .steady:       return Neon.gold
        case .overreaching: return Neon.orange
        }
    }

    // MARK: - HRV

    private var hrvChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Variabilidad cardiaca (HRV)").font(.mSubheadline.weight(.semibold))
            Text("Qué tan recuperado está tu cuerpo. Por encima de tu base = mejor recuperado; "
                + "por debajo = fatiga o estrés. Suele bajar tras entrenar fuerte.")
                .font(.mCaption2).foregroundStyle(.secondary)

            Chart {
                // Días con entrenamiento (referencia discreta detrás de la serie).
                ForEach(trend.trainingDays, id: \.self) { day in
                    RuleMark(x: .value("Día", day, unit: .day))
                        .foregroundStyle(.secondary.opacity(0.12))
                        .lineStyle(StrokeStyle(lineWidth: 3))
                }
                // Base de HRV.
                if let baseline = trend.hrvBaseline {
                    RuleMark(y: .value("Base", baseline))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                // Serie de HRV.
                ForEach(trend.hrvValues) { point in
                    LineMark(x: .value("Día", point.date, unit: .day),
                             y: .value("HRV", point.hrv ?? 0))
                        .foregroundStyle(Neon.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxisLabel("ms")
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 140)

            legend {
                legendLine(color: Neon.accent, text: "Tu HRV")
                legendDashed(text: "Tu base")
                if !trend.trainingDays.isEmpty {
                    legendMark(text: "Día que entrenaste")
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Sueño

    private var sleepChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sueño por noche").font(.mSubheadline.weight(.semibold))
            Text("Cuánto dormiste cada noche. Dormir bien sube tu HRV y acelera tu recuperación; "
                + "la línea punteada es la meta de 7 h.")
                .font(.mCaption2).foregroundStyle(.secondary)

            Chart {
                RuleMark(y: .value("Meta", 7))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                ForEach(trend.sleepValues) { point in
                    BarMark(x: .value("Día", point.date, unit: .day),
                            y: .value("Horas", point.sleepHours ?? 0))
                        .foregroundStyle(Neon.teal)
                        .cornerRadius(3)
                }
            }
            .chartYAxisLabel("horas")
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 140)

            legend {
                legendBar(color: Neon.teal, text: "Horas dormidas")
                legendDashed(text: "Meta (7 h)")
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Leyenda

    private func legend<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 14) { content() }
            .font(.mCaption2)
            .foregroundStyle(.secondary)
    }

    private func legendLine(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 14, height: 3)
            Text(text)
        }
    }

    private func legendBar(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 12)
            Text(text)
        }
    }

    private func legendDashed(text: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(.secondary).frame(width: 14, height: 2).opacity(0.6)
            Text(text)
        }
    }

    private func legendMark(text: String) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(.secondary.opacity(0.35)).frame(width: 2, height: 12)
            Text(text)
        }
    }
}
