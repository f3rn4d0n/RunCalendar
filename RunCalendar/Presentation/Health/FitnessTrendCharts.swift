import SwiftUI
import Charts

/// Gráficas de tendencia de condición: volumen semanal (barras), ritmo por corrida
/// (línea) y VO₂max en el tiempo (línea). Interactivas: toca para ver el valor.
struct FitnessTrendSection: View {
    let trend: FitnessTrend

    @State private var volumeSel: Date?
    @State private var paceSel: Date?
    @State private var cadenceSel: Date?
    @State private var vo2Sel: Date?
    @State private var hrvSel: Date?

    /// Corridas con cadencia registrada (cronológico, ya viene ordenado).
    private var cadence: [RunPacePoint] { trend.pace.filter { $0.stepsPerMinute != nil } }

    private var enoughVolume: Bool { trend.weeklyVolume.count >= 2 }
    private var enoughPace: Bool { trend.pace.count >= 3 }
    private var enoughCadence: Bool { cadence.count >= 3 }
    private var enoughVO2: Bool { trend.vo2Max.count >= 2 }
    /// Dos puntos bastan para dibujar una línea, pero no para decir nada: el veredicto necesita dos
    /// bloques de cuatro semanas. Se pinta desde ahí para no insinuar una tendencia que no existe.
    private var enoughHRV: Bool { trend.hrvBaseline.count >= HRVPoint.weeksForVerdict }

    var body: some View {
        Section {
            if enoughVolume { volumeChart }
            if enoughPace { paceChart }
            if enoughCadence { cadenceChart }
            if enoughVO2 { vo2Chart }
            if enoughHRV { hrvChart }
            if !enoughVolume && !enoughPace && !enoughVO2 {
                Label("Corre unas semanas más para ver tu tendencia aquí.",
                      systemImage: "chart.bar.xaxis")
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
        } header: {
            Text("Tu evolución")
            SectionNote("Toca cualquier punto para ver su valor. El VO₂max y la línea base de HRV "
                        + "se mueven en **meses**: son señales de adaptación, no de cómo estás hoy "
                        + "— eso vive en Recuperación. El HRV de Apple Salud se muestrea cuando el "
                        + "reloj puede, no en una medición matinal controlada, así que sirve para "
                        + "ver tu tendencia y no para compararte con nadie.")
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

    // MARK: - Cadencia por corrida

    private var cadenceChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cadencia por corrida").font(.mSubheadline.weight(.semibold))
            Text("Pasos por minuto. Una cadencia más alta suele significar zancadas más cortas "
                + "y menos impacto: si sube, tu técnica mejora.")
                .font(.mCaption2).foregroundStyle(.secondary)

            Chart {
                ForEach(cadence) { point in
                    LineMark(x: .value("Fecha", point.date),
                             y: .value("Cadencia", point.stepsPerMinute ?? 0))
                        .foregroundStyle(Neon.pink)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Fecha", point.date),
                              y: .value("Cadencia", point.stepsPerMinute ?? 0))
                        .foregroundStyle(Neon.pink)
                        .symbolSize(30)
                }
                if let sel = nearestByDate(cadenceSel, in: cadence, \.date), let spm = sel.stepsPerMinute {
                    chartSelectionMark(date: sel.date,
                                       title: sel.date.mediumString(),
                                       value: "\(spm) ppm")
                }
            }
            .chartXSelection(value: $cadenceSel)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel("ppm")
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis {
                AxisMarks { AxisValueLabel(format: .dateTime.day().month(.abbreviated)) }
            }
            .frame(height: 150)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Línea base de HRV

    /// La **línea base** de HRV en meses, que no es lo mismo que el HRV de hoy.
    ///
    /// El dato diario ya está en *Recuperación* y responde "¿puedo apretar hoy?". Éste responde
    /// "¿me estoy adaptando?", y por eso vive aquí, junto al VO₂max y el volumen.
    private var hrvChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Línea base de HRV").font(.mSubheadline.weight(.semibold))
            Text("Promedio semanal (ms). Compara tus últimas 4 semanas con las 4 anteriores — "
                 + "nunca con las de otra persona: el valor absoluto no dice nada entre individuos.")
                .font(.mCaption2).foregroundStyle(.secondary)

            Chart {
                ForEach(trend.hrvBaseline) { point in
                    LineMark(x: .value("Fecha", point.date),
                             y: .value("HRV", point.milliseconds))
                        .foregroundStyle(Neon.teal)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Fecha", point.date),
                              y: .value("HRV", point.milliseconds))
                        .foregroundStyle(Neon.teal)
                        .symbolSize(30)
                }
                if let sel = nearestByDate(hrvSel, in: trend.hrvBaseline, \.date) {
                    chartSelectionMark(date: sel.date,
                                       title: sel.date.mediumString(),
                                       value: "\(Int(sel.milliseconds)) ms")
                }
            }
            .chartXSelection(value: $hrvSel)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 150)

            hrvVerdict
        }
        .padding(.vertical, 4)
    }

    /// Qué significa la curva, en una frase — y qué **no** significa.
    @ViewBuilder private var hrvVerdict: some View {
        switch HRVPoint.trend(of: trend.hrvBaseline) {
        case .rising:
            verdictLine("Tu base viene subiendo", Neon.green,
                        "Suele acompañar a una buena adaptación al entrenamiento. No es una nota: "
                        + "es una señal más, y el sueño y el estrés la mueven tanto como correr.")
        case .stable:
            verdictLine("Tu base se mantiene", Neon.gold,
                        "Lo normal en un bloque estable. Que no suba no significa que no estés "
                        + "mejorando — el HRV no es un marcador de rendimiento.")
        case .falling:
            verdictLine("Tu base viene bajando", Neon.orange,
                        "Puede ser carga acumulada sin recuperar, pero también sueño, enfermedad, "
                        + "alcohol o estrés. Míralo junto a tu carga y a cómo te sientes, no solo.")
        case .notEnough:
            EmptyView()
        }
    }

    private func verdictLine(_ title: String, _ color: Color, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.mCaption.weight(.semibold)).foregroundStyle(color)
            Text(detail).font(.mCaption2).foregroundStyle(.secondary)
        }
        .padding(.top, 2)
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
