import SwiftUI

/// Pantalla de condición física: conecta con Salud, muestra el resumen y el
/// estimado de preparación por distancia.
struct HealthView: View {
    @State var viewModel: HealthViewModel
    let racesViewModel: RacesViewModel
    @State var goalsViewModel: GoalsViewModel
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
                    loadingSkeleton
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
            .background(Neon.background.ignoresSafeArea())
            .navigationTitle("Progreso")
            .task { await viewModel.onAppear() }
        }
    }

    /// Skeleton mientras lee Salud: cards con la misma silueta que el contenido real, con brillo.
    private var loadingSkeleton: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in skeletonCard }
            }
            .padding(16)
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Circle().fill(Color.primary.opacity(0.08)).frame(width: 66, height: 66)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.12))
                        .frame(width: 120, height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08))
                        .frame(width: 180, height: 10)
                }
                Spacer()
            }
            RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)).frame(height: 10)
            RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08))
                .frame(width: 220, height: 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Neon.surface, in: RoundedRectangle(cornerRadius: 18))
        .shimmering()
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

    /// Orden de la pantalla. El **porqué** está en `docs/ux-jerarquia.md`; en corto:
    ///
    /// - *Hoy* ya responde "¿cómo estoy hoy?" con el anillo de recuperación, así que aquí se
    ///   responde "¿dónde estoy y hacia dónde voy?" — y la recuperación baja de puesto sin perder
    ///   nada, porque su titular vive en otra pantalla.
    /// - Lo **accionable pendiente** manda: un check-in sin hacer va arriba; hecho, se va al final.
    ///   Una tarea cumplida es ruido en un informe.
    /// - Un tema, un bloque. La recuperación estaba en cuatro pedazos separados por otras
    ///   secciones, y el readiness partido en dos con nueve secciones en medio.
    /// - Lo avanzado no se esconde, **deja de competir**: baja en la página o se pliega. Quien
    ///   busca su VO₂max lo encuentra; a quien solo quiere sus kilómetros no le estorba.
    private func loaded(_ data: HealthLoaded) -> some View {
        List {
            // 1. Lo único que la pantalla te pide hacer, y solo si está pendiente.
            if viewModel.todayCheckIn == nil { checkInSection }

            // 2. Dónde estás.
            summarySection(data.summary)

            // 3. Para qué te está sirviendo: tus carreras y las distancias, juntas.
            raceReadinessSection(data: data)
            distanceReadinessSection(data: data)

            // 4. Si puedes apretar. Un solo bloque, no cuatro pedazos, y dentro de él en orden
            //    de cercanía: el estimado de hoy, qué tan fiable es, tu tendencia, tu carga.
            //    "¿Acierta el modelo?" estaba detrás de la tendencia, y mide el estimado — no la
            //    tendencia. Va pegado a lo que juzga.
            if let recovery = data.recovery {
                recoverySection(recovery)
            }
            if viewModel.recentCheckIns.count >= 3 {
                RecoveryAccuracyChart(checkIns: viewModel.recentCheckIns)
            }
            if let trend = data.recoveryTrend {
                RecoveryTrendSection(trend: trend)
            }
            if let workload = data.workload {
                workloadSection(workload)
            }

            // 5. Cómo evolucionas. Al final: estar abajo ya es jerarquía suficiente — quien no las
            // busca no llega, y a quien sí, un plegado solo le costaría un toque de más.
            if let fitnessTrend = data.fitnessTrend {
                FitnessTrendSection(trend: fitnessTrend)
            }

            // 6. Registrar. Las entradas estaban en medio del informe e interrumpían la lectura.
            if viewModel.todayCheckIn != nil { checkInSection }
            bodyReviewSection
        }
        .scrollContentBackground(.hidden)
        .listRowBackground(Neon.surface)
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private func raceReadinessSection(data: HealthLoaded) -> some View {
        let rows = targetRaces
            // Consciente de la fecha: el consejo de cada carrera depende de las semanas que faltan.
            .compactMap { race -> (Race, RaceReadiness)? in
                viewModel.readiness(for: race).map { (race, $0) }
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
                SectionNote("Toca una carrera para ver qué mejorar antes del evento.")
            }
        }
    }

    /// Readiness **por distancia**: ¿podría con un 21K?
    ///
    /// Va pegada a la de tus carreras porque responden la misma pregunta con distinto alcance —
    /// una mira tu calendario y la otra es exploratoria. Antes estaban en extremos opuestos de la
    /// pantalla, con nueve secciones en medio, y eso era buena parte de la sensación de desorden.
    private func distanceReadinessSection(data: HealthLoaded) -> some View {
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
            SectionNote("Toca una distancia para ver qué mejorar. Estimado orientativo, no es "
                        + "consejo médico.")
        }
    }

    /// Review dominical (Fase 2). Vive junto al check-in diario: ambos son "cómo voy".
    @ViewBuilder
    private var bodyReviewSection: some View {
        Section {
            NavigationLink {
                WeightLogView(viewModel: goalsViewModel)
            } label: {
                HStack {
                    Label("Cuerpo y review semanal", systemImage: "figure.walk")
                    Spacer()
                    if goalsViewModel.hasReviewThisWeek {
                        Text("Hecho").font(.mCaption).foregroundStyle(Neon.green)
                    } else {
                        Text("Pendiente").font(.mCaption).foregroundStyle(.secondary)
                    }
                }
            }
            SectionNote("Peso, cintura, energía y hambre. Las medidas se guardan en Salud; "
                        + "la cintura detecta el progreso que la báscula esconde.")
        }
    }

    @ViewBuilder
    private var checkInSection: some View {
        Section {
            if let checkIn = viewModel.todayCheckIn, !editingCheckIn {
                // Compacto: ya registraste hoy.
                HStack {
                    Label("Hoy: \(FeelingPicker.label(checkIn.feeling))",
                          systemImage: "\(checkIn.feeling).circle.fill")
                        .foregroundStyle(FeelingPicker.color(checkIn.feeling))
                    Spacer()
                    Button("Cambiar") { editingCheckIn = true }.font(.mSubheadline)
                }
            } else {
                FeelingPicker(selected: viewModel.todayCheckIn?.feeling) { value in
                    await viewModel.submitCheckIn(feeling: value)
                    editingCheckIn = false
                }
            }
        } header: {
            Text("¿Cómo te sientes hoy?")
            if viewModel.todayCheckIn == nil || editingCheckIn {
                SectionNote("Tu registro se compara con el estimado del modelo para "
                            + "personalizarlo con el tiempo.")
            }
        }
    }

    private func workloadSection(_ w: WorkloadRatio) -> some View {
        Section {
            HStack(spacing: 16) {
                ProgressRing(progress: w.ringFraction, color: workloadColor(w.zone), lineWidth: 7, size: 66) {
                    Text(w.ratioText).font(.marker(15))
                        .foregroundStyle(workloadColor(w.zone))
                        .lineLimit(1).minimumScaleFactor(0.5).frame(width: 46)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.zone.title).font(.mHeadline).foregroundStyle(workloadColor(w.zone))
                    Text("Esta semana \(w.acuteMinutes) min · promedio \(w.weeklyAverageMinutes) min/sem")
                        .font(.mSubheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(w.note).font(.mCaption).foregroundStyle(.secondary)
        } header: {
            Text("Carga de entrenamiento")
            SectionNote("Relación carga aguda:crónica (ACWR): tu semana vs. tu promedio de 4 "
                        + "semanas. Usa tus entrenamientos registrados, ponderados por esfuerzo "
                        + "(RPE): una sesión intensa pesa más que una suave de la misma duración.")
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
            SectionNote("Estimado orientativo a partir de tu HRV, FC en reposo y carga "
                        + "reciente. No es consejo médico.")
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
    /// Dónde estás. Seis métricas, de lo accionable a lo que hay que ir a buscar.
    ///
    /// Estuvieron plegadas tras un "Más detalle" y se quitó: eran **tres filas**, y cobrar un toque
    /// por tres filas no es jerarquía, es fricción. La sección ya está arriba y ordenada de lo
    /// esencial a lo avanzado, que es suficiente — ver el criterio 5 en `docs/ux-jerarquia.md`,
    /// que dice *baja **o** pliega*, no las dos.
    private func summarySection(_ summary: FitnessSummary) -> some View {
        Section {
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
                MetricRow(label: "VO₂max",
                          value: vo2.formatted(.number.precision(.fractionLength(1))),
                          icon: "lungs.fill",
                          info: HealthMetricInfo.vo2Max(vo2, age: summary.age))
            }
            if let resting = summary.restingHeartRate {
                MetricRow(label: "FC en reposo", value: "\(Int(resting)) lpm", icon: "heart.fill",
                          info: HealthMetricInfo.restingHeartRate(resting))
            }
        } header: {
            Text("Resumen (\(summary.weeks) semanas)")
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
