import SwiftUI

/// Récords de levantamiento, por ejercicio: mejor esfuerzo (1RM estimado o repeticiones, según el
/// estilo de carga) y progresión. Copia estructural de `PersonalRecordsView`, sin estado de carga
/// (todo local, síncrono) ni badge de fuente (una sola fuente: el registro manual).
struct LiftRecordsView: View {
    let trainingViewModel: TrainingViewModel
    @Environment(\.dismiss) private var dismiss

    private var records: [LiftRecord] {
        LiftRecords.compute(sessions: trainingViewModel.sessions)
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "Sin récords de fuerza",
                        message: "Registra las series de un entrenamiento de CrossFit —ejercicio, "
                            + "peso y repeticiones— y aquí verás tu mejor levantamiento estimado."
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            Section(record.exercise.displayName) {
                                recordContent(record)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Récords de fuerza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private func recordContent(_ r: LiftRecord) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(heroText(r.best.set))
                    .font(.mLargeTitle.bold()).foregroundStyle(.tint).monospacedDigit()
                Text(subtitleText(r.best.set))
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "medal.fill").font(.system(size: 30)).foregroundStyle(Neon.gold)
        }

        HStack(spacing: 8) {
            Text(r.best.sessionTitle).font(.mSubheadline).lineLimit(1)
            Spacer()
            Text(r.best.date.mediumString()).font(.mCaption).foregroundStyle(.secondary)
        }

        if r.history.count > 1 {
            DisclosureGroup("Progresión · \(r.history.count) esfuerzos") {
                ForEach(r.history.reversed()) { effort in
                    historyRow(effort, isBest: effort.id == r.best.id)
                }
            }
        }
    }

    private func historyRow(_ effort: LiftEffort, isBest: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(effort.date.mediumString()).font(.mCaption).foregroundStyle(.secondary)
                Text(effort.sessionTitle).font(.mCaption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer()
            Text(heroText(effort.set)).font(.mSubheadline.monospacedDigit())
            if isBest {
                Image(systemName: "medal.fill").font(.mCaption).foregroundStyle(Neon.gold)
                    .accessibilityLabel("Récord")
            }
        }
    }

    /// El número grande: 1RM estimado en carga externa, repeticiones en peso corporal.
    private func heroText(_ set: StrengthSet) -> String {
        switch set.exercise.loadStyle {
        case .external:
            return set.estimatedOneRM.map { "\(Goal.trim($0)) kg" } ?? "—"
        case .bodyweight:
            return "\(set.reps) reps"
        }
    }

    /// La palabra "estimado" siempre visible en carga externa: es un número derivado de una
    /// fórmula sin calibrar, y presentarlo como "tu 1RM" sería el dato inventado que la app se
    /// prohíbe mostrar.
    private func subtitleText(_ set: StrengthSet) -> String {
        switch set.exercise.loadStyle {
        case .external:
            return "1RM estimado · \(Goal.trim(set.weightKg)) kg × \(set.reps)"
        case .bodyweight:
            return set.weightKg > 0 ? "+\(Goal.trim(set.weightKg)) kg de lastre" : "sin lastre"
        }
    }
}
