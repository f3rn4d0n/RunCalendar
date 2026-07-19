import SwiftUI

/// Pantalla de condición física: conecta con Salud, muestra el resumen y el
/// estimado de preparación por distancia.
struct HealthView: View {
    @State var viewModel: HealthViewModel
    let racesViewModel: RacesViewModel
    @State private var editingCheckIn = false

    /// Carreras objetivo para la preparación: todas las prioritarias próximas.
    /// Si no hay prioritarias, la próxima más cercana. El orden y el límite de
    /// visualización se aplican después, por urgencia de preparación.
    private var targetRaces: [Race] {
        let upcoming = racesViewModel.races
            .filter { $0.date.daysFromNow() >= 0 }
            .sorted { $0.date < $1.date }
        let priority = upcoming.filter(\.isPriority)
        return priority.isEmpty ? Array(upcoming.prefix(1)) : priority
    }

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
            raceReadinessSection(data: data)

            if let recovery = data.recovery {
                recoverySection(recovery)
            }

            checkInSection

            if viewModel.recentCheckIns.count >= 3 {
                RecoveryAccuracyChart(checkIns: viewModel.recentCheckIns)
            }

#if DEBUG
            Section {
                Button("Sembrar 18 check-ins (debug)") {
                    Task { await viewModel.seedDemoCheckIns() }
                }
            } footer: {
                Text("Solo desarrollo: simula 2+ semanas de registros para ver la calibración. Se borra al reiniciar.")
            }
#endif

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
    private func raceReadinessSection(data: HealthLoaded) -> some View {
        let rows = targetRaces
            .compactMap { race -> (Race, RaceReadiness)? in
                data.readiness.first { $0.distance == race.discipline }.map { (race, $0) }
            }
            // Solo lo accionable: oculta las que ya estás listo (eso queda en el detalle).
            .filter { $0.1.level != .ready }
            // Primero lo que más falta preparar; a igual nivel, la más próxima antes.
            .sorted { lhs, rhs in
                if lhs.1.level.prepPriority != rhs.1.level.prepPriority {
                    return lhs.1.level.prepPriority < rhs.1.level.prepPriority
                }
                return lhs.0.date < rhs.0.date
            }
        if !rows.isEmpty {
            Section {
                ForEach(rows, id: \.0.id) { race, readiness in
                    NavigationLink {
                        ReadinessDetailView(readiness: readiness)
                    } label: {
                        RaceReadinessRow(race: race, readiness: readiness)
                    }
                }
            } header: {
                Text(rows.contains { $0.0.isPriority } ? "Tus carreras prioritarias" : "Tu próxima carrera")
            } footer: {
                Text("Toca una carrera para ver qué mejorar antes del evento.")
            }
        }
    }

    @ViewBuilder
    private var checkInSection: some View {
        Section {
            if let checkIn = viewModel.todayCheckIn, !editingCheckIn {
                // Compacto: ya registraste hoy.
                HStack {
                    Label("Hoy: \(feelingLabel(checkIn.feeling))", systemImage: "\(checkIn.feeling).circle.fill")
                        .foregroundStyle(feelingColor(checkIn.feeling))
                    Spacer()
                    Button("Cambiar") { editingCheckIn = true }.font(.mSubheadline)
                }
            } else {
                feelingButtons(selected: viewModel.todayCheckIn?.feeling)
            }
        } header: {
            Text("¿Cómo te sientes hoy?")
        } footer: {
            if viewModel.todayCheckIn == nil || editingCheckIn {
                Text("Tu registro se compara con el estimado del modelo para personalizarlo con el tiempo.")
            }
        }
    }

    private func feelingButtons(selected: Int?) -> some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    Task {
                        await viewModel.submitCheckIn(feeling: value)
                        editingCheckIn = false
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "\(value).circle.fill").font(.system(size: 26))
                            .foregroundStyle(feelingColor(value))
                        Text(feelingLabel(value)).font(.mCaption2).lineLimit(1)
                            .foregroundStyle(selected == value ? AnyShapeStyle(feelingColor(value))
                                                               : AnyShapeStyle(.secondary))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected == value ? AnyShapeStyle(feelingColor(value).opacity(0.16))
                                                  : AnyShapeStyle(Color.clear),
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private func feelingLabel(_ value: Int) -> String {
        switch value {
        case 1: return "Agotado"
        case 2: return "Cansado"
        case 3: return "Normal"
        case 4: return "Bien"
        default: return "Fresco"
        }
    }

    /// Color por nivel de cansancio: rojo (agotado) → verde (fresco).
    private func feelingColor(_ value: Int) -> Color {
        switch value {
        case 1: return Color(red: 0.90, green: 0.25, blue: 0.30)
        case 2: return Neon.orange
        case 3: return Neon.gold
        case 4: return Neon.teal
        default: return Neon.green
        }
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
                + "Usa tus entrenamientos registrados, ponderados por esfuerzo (RPE): una sesión "
                + "intensa pesa más que una suave de la misma duración.")
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
            HStack(spacing: 16) {
                ProgressRing(progress: recoveryFraction(r.level),
                             color: recoveryColor(r.level), lineWidth: 7, size: 66) {
                    Text(r.remainingHours > 0 ? r.remainingText.replacingOccurrences(of: "~", with: "") : "Listo")
                        .font(.marker(r.remainingHours > 0 ? 15 : 13))
                        .foregroundStyle(recoveryColor(r.level))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(width: 46)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.level.rawValue).font(.mHeadline)
                    Text(r.remainingHours > 0 ? "para estar listo" : "Listo para entrenar")
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

            if let calibration = r.calibration {
                Label(calibration.summary, systemImage: "slider.horizontal.3")
                    .font(.mCaption).foregroundStyle(Neon.accent)
            }

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

    /// Llenado del anillo según el nivel (cualitativo: no tenemos un % exacto de recuperación).
    private func recoveryFraction(_ level: RecoveryLevel) -> Double {
        switch level {
        case .recovered: return 1.0
        case .partial:   return 0.6
        case .fatigued:  return 0.3
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
