import SwiftUI

/// Pantalla de condición física: conecta con Salud, muestra el resumen y el
/// estimado de preparación por distancia.
struct HealthView: View {
    @State var viewModel: HealthViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .unavailable:
                    EmptyStateView(
                        icon: "heart.slash",
                        title: "No disponible aquí",
                        message: "La condición física con Apple Salud está disponible en tu iPhone."
                    )
                case .needsAuthorization:
                    connectPrompt
                case .loading:
                    ProgressView("Leyendo Salud…")
                case .loaded(let data):
                    loaded(data)
                case .error(let message):
                    VStack(spacing: 16) {
                        EmptyStateView(icon: "exclamationmark.triangle", title: "Ups", message: message)
                        Button("Reintentar") { Task { await viewModel.connect() } }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Condición")
            .task { await viewModel.onAppear() }
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(Neon.logoGradient)
            Text("Conecta con Apple Salud para ver tu condición y saber si estás listo para tu próxima carrera.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Conectar con Salud") { Task { await viewModel.connect() } }
                .buttonStyle(NeonButtonStyle())
                .padding(.horizontal, 40)
        }
        .padding()
    }

    private func loaded(_ data: HealthLoaded) -> some View {
        List {
            if let recovery = data.recovery {
                recoverySection(recovery)
            }
            if let trend = data.recoveryTrend {
                RecoveryTrendSection(trend: trend)
            }
            if let workload = data.workload {
                workloadSection(workload)
            }

            summarySection(data.summary)

            if let fitnessTrend = data.fitnessTrend {
                FitnessTrendSection(trend: fitnessTrend)
            }

            Section {
                ForEach(data.readiness) { item in
                    NavigationLink {
                        ReadinessDetailView(readiness: item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.level.systemImage)
                                .foregroundStyle(color(for: item.level))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.distance.displayName) · \(item.level.rawValue)")
                                Text(item.note).font(.mCaption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("¿Listo para…?")
            } footer: {
                Text("Toca una distancia para ver qué mejorar. Estimado orientativo, no es consejo médico.")
            }
        }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private func workloadSection(_ w: WorkloadRatio) -> some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: w.zone.systemImage)
                    .font(.system(size: 30))
                    .foregroundStyle(workloadColor(w.zone))
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(w.ratioText).font(.mTitle3.bold())
                        Text(w.zone.title)
                            .font(.mCaption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(workloadColor(w.zone).opacity(0.15), in: Capsule())
                            .foregroundStyle(workloadColor(w.zone))
                    }
                    Text("Esta semana \(w.acuteMinutes) min · promedio \(w.weeklyAverageMinutes) min/sem")
                        .font(.mSubheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(w.note).font(.mCaption).foregroundStyle(.secondary)
        } header: {
            Text("Carga de entrenamiento")
        } footer: {
            Text("Relación carga aguda:crónica (ACWR): tu semana vs. tu promedio de 4 semanas. "
                + "Considera todos tus entrenamientos de Salud, no solo carreras.")
        }
    }

    private func workloadColor(_ zone: WorkloadZone) -> Color {
        switch zone {
        case .detraining: return Neon.accent
        case .optimal:    return Neon.green
        case .caution:    return Neon.gold
        case .highRisk:   return Neon.orange
        }
    }

    @ViewBuilder
    private func recoverySection(_ r: RecoveryEstimate) -> some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: r.level.systemImage)
                    .font(.system(size: 30))
                    .foregroundStyle(recoveryColor(r.level))
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.level.rawValue).font(.mHeadline)
                    Text(r.remainingHours > 0 ? "Listo en \(r.remainingText)" : "Listo para entrenar")
                        .font(.mSubheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let current = r.currentHRV, let base = r.baselineHRV {
                MetricRow(label: "HRV (SDNN)",
                          value: "\(Int(current)) ms · base \(Int(base)) ms",
                          icon: "waveform.path.ecg",
                          info: HealthMetricInfo.hrv(current: current, baseline: base,
                                                     deviationPct: r.hrvDeviationPct))
            }

            if let sleep = r.sleepHours {
                MetricRow(label: "Sueño (anoche)",
                          value: "\(sleep.formatted(.number.precision(.fractionLength(1)))) h",
                          icon: "bed.double.fill",
                          info: HealthMetricInfo.sleep(sleep))
            }

            Text(r.note).font(.mCaption).foregroundStyle(.secondary)

            DisclosureGroup("Qué hacer") {
                ForEach(r.tips, id: \.self) { tip in
                    Label(tip, systemImage: "checkmark.circle")
                        .font(.mCaption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Recuperación")
        } footer: {
            Text("Estimado orientativo a partir de tu HRV, FC en reposo y carga reciente. No es consejo médico.")
        }
    }

    private func recoveryColor(_ level: RecoveryLevel) -> Color {
        switch level {
        case .recovered: return Neon.green
        case .partial:   return Neon.gold
        case .fatigued:  return Neon.orange
        }
    }

    @ViewBuilder
    private func summarySection(_ summary: FitnessSummary) -> some View {
        Section("Resumen (\(summary.weeks) semanas)") {
            MetricRow(label: "Esta semana (7 días)", value: km(summary.last7DaysKm), icon: "calendar",
                      info: HealthMetricInfo.thisWeek())
            MetricRow(label: "Promedio semanal (\(summary.weeks) sem)",
                      value: km(summary.weeklyDistanceKm), icon: "chart.bar.fill",
                      info: HealthMetricInfo.weeklyAverage(weeks: summary.weeks))
            MetricRow(label: "Carrera más larga", value: km(summary.longestRunKm), icon: "figure.run",
                      info: HealthMetricInfo.longestRun())
            MetricRow(label: "Entrenamientos", value: "\(summary.runCount)", icon: "number",
                      info: HealthMetricInfo.runCount())
            if let vo2 = summary.vo2Max {
                MetricRow(label: "VO₂max", value: vo2.formatted(.number.precision(.fractionLength(1))),
                          icon: "lungs.fill",
                          info: HealthMetricInfo.vo2Max(vo2, age: summary.age))
            }
            if let resting = summary.restingHeartRate {
                MetricRow(label: "FC en reposo", value: "\(Int(resting)) lpm", icon: "heart.fill",
                          info: HealthMetricInfo.restingHeartRate(resting))
            }
        }
    }

    private func km(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)))) km"
    }

    private func color(for level: ReadinessLevel) -> Color {
        switch level {
        case .ready: return Neon.green
        case .almost: return Neon.gold
        case .building: return Neon.orange
        }
    }
}
