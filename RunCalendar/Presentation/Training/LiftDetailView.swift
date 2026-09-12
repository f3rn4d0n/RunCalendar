import SwiftUI
import Charts

/// Detalle de un ejercicio: 1RM estimado + tabla de porcentajes (carga externa), gráfica de
/// resultados en el tiempo, y los últimos 6 resultados editables.
struct LiftDetailView: View {
    let weightliftingViewModel: WeightliftingViewModel
    let exercise: StrengthExercise

    @State private var addingNew = false
    @State private var editingEffort: LiftEffort?
    @State private var chartSelection: Date?

    /// Series submáximas para programar, no un dato medido — por eso siempre junto a "estimado".
    private static let percentages: [Int] = [95, 90, 85, 80, 75, 70, 65, 60, 55]

    private var record: LiftRecord? {
        weightliftingViewModel.records.first { $0.exercise == exercise }
    }
    private var history: [LiftEffort] {
        weightliftingViewModel.history(for: exercise)
    }
    private var lastSix: [LiftEffort] {
        Array(history.suffix(6))
    }

    var body: some View {
        Group {
            if history.isEmpty {
                EmptyStateView(
                    icon: "dumbbell",
                    title: "Sin resultados",
                    message: "Registra tu primer resultado de \(exercise.displayName.lowercased())."
                )
            } else {
                List {
                    if let record {
                        Section {
                            heroRow(record.best)
                            if exercise.loadStyle == .external, let oneRM = record.best.estimatedOneRM {
                                percentagesGrid(oneRM: oneRM)
                            }
                        } header: {
                            Text(exercise.loadStyle == .external ? "1RM estimado" : "Mejor resultado")
                        }
                    }

                    Section("Resultados") {
                        chart
                    }

                    Section("Últimos \(lastSix.count) resultados") {
                        ForEach(lastSix) { effort in
                            resultRow(effort)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(Neon.surface)
            }
        }
        .background(Neon.background.ignoresSafeArea())
        .navigationTitle(exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nuevo") { addingNew = true }
            }
        }
        .sheet(isPresented: $addingNew) {
            LiftEntrySheet(weightliftingViewModel: weightliftingViewModel, exercise: exercise, effort: nil)
        }
        .sheet(item: $editingEffort) { effort in
            LiftEntrySheet(weightliftingViewModel: weightliftingViewModel, exercise: exercise, effort: effort)
        }
    }

    // MARK: - Hero + porcentajes

    private func heroRow(_ best: LiftEffort) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(heroText(best)).font(.mLargeTitle.bold()).monospacedDigit()
                if exercise.loadStyle == .external {
                    Text("estimado").font(.mCaption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "medal.fill").font(.system(size: 30)).foregroundStyle(Neon.gold)
        }
        .padding(.vertical, 4)
    }

    private func heroText(_ effort: LiftEffort) -> String {
        switch exercise.loadStyle {
        case .external:
            return effort.estimatedOneRM.map { "\(Goal.trim($0)) kg" } ?? "—"
        case .bodyweight:
            return "\(effort.reps) reps"
        }
    }

    private func percentagesGrid(oneRM: Double) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Self.percentages, id: \.self) { pct in
                VStack(spacing: 2) {
                    Text("\(Goal.trim(oneRM * Double(pct) / 100)) kg")
                        .font(.mSubheadline.weight(.semibold))
                    Text("\(pct)%").font(.mCaption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Neon.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Gráfica

    /// Peso crudo en carga externa (no el 1RM estimado: así se ve el dato real, sin que la
    /// fórmula lo distorsione); repeticiones en peso corporal.
    private var chart: some View {
        Chart {
            ForEach(history) { effort in
                BarMark(x: .value("Fecha", effort.date, unit: .day),
                        y: .value(chartUnitLabel, chartValue(effort)))
                    .foregroundStyle(Neon.accent)
                    .cornerRadius(3)
            }
            if let sel = nearestByDate(chartSelection, in: history, \.date) {
                chartSelectionMark(date: sel.date, title: sel.date.mediumString(),
                                   value: chartValueText(sel))
            }
        }
        .chartXSelection(value: $chartSelection)
        .chartYAxisLabel(chartUnitLabel)
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis {
            AxisMarks { AxisValueLabel(format: .dateTime.day().month(.abbreviated)) }
        }
        .frame(height: 180)
        .padding(.vertical, 4)
    }

    private var chartUnitLabel: String { exercise.loadStyle == .external ? "kg" : "reps" }

    private func chartValue(_ effort: LiftEffort) -> Double {
        exercise.loadStyle == .external ? effort.weightKg : Double(effort.reps)
    }

    private func chartValueText(_ effort: LiftEffort) -> String {
        exercise.loadStyle == .external
            ? "\(Goal.trim(effort.weightKg)) kg"
            : "\(effort.reps) reps"
    }

    // MARK: - Últimos resultados

    private func resultRow(_ effort: LiftEffort) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(effort.date.mediumString()).font(.mSubheadline)
                Text("\(Goal.trim(effort.weightKg)) kg × \(effort.reps)")
                    .font(.mCaption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { editingEffort = effort } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Editar resultado")
        }
    }
}
