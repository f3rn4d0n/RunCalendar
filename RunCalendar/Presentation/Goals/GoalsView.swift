import SwiftUI

/// Objetivos del atleta: cada meta es una "misión" (número héroe, progreso claro, días
/// restantes, confianza cualitativa y coach insight). Fase 1 de la visión, look de rediseño.
struct GoalsView: View {
    @State var viewModel: GoalsViewModel
    @State private var editing: Goal?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.goals.isEmpty {
                    EmptyStateView(
                        icon: "target",
                        title: "Sin objetivos",
                        message: "Define tu primera meta (tiempo, VO₂max o peso) con el botón +."
                    )
                } else {
                    List {
                        ForEach(viewModel.goals) { goal in
                            GoalHeroCard(
                                goal: goal,
                                progress: viewModel.progress(for: goal),
                                confidence: viewModel.confidence(for: goal),
                                insight: viewModel.coachInsight(for: goal)
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = goal }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(goal) }
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Neon.background.ignoresSafeArea())
            .navigationTitle("Objetivos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Agregar objetivo")
                }
            }
            .sheet(isPresented: $isCreating) { GoalFormView(viewModel: viewModel, goal: nil) }
            .sheet(item: $editing) { goal in GoalFormView(viewModel: viewModel, goal: goal) }
        }
    }
}

/// Tarjeta-misión de una meta.
struct GoalHeroCard: View {
    let goal: Goal
    let progress: GoalProgress
    let confidence: GoalConfidence?
    let insight: String?

    private var targetText: String { Goal.format(goal.targetValue, type: goal.type) }
    private var pct: Int? { progress.fraction.map { Int(($0 * 100).rounded()) } }

    private var caption: String {
        progress.achieved
            ? "meta \(targetText) · ¡logrado!"
            : "actual \(progress.currentText) → meta \(targetText) · \(progress.deltaText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Eyebrow
            HStack(spacing: 7) {
                Circle().fill(Neon.accent).frame(width: 6, height: 6)
                Text(goal.type.displayName.uppercased())
                    .font(.mCaption).tracking(1).foregroundStyle(Neon.accent)
                Spacer()
                if progress.achieved {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Neon.green)
                        .accessibilityLabel("Lograda")
                }
            }

            // Número héroe
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(goal.heroTag)
                    .font(.mFootnote).fontWeight(.bold)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Neon.surfaceElevated, in: RoundedRectangle(cornerRadius: 9))
                Text(goal.heroValue)
                    .font(.marker(44))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }

            // Progreso
            VStack(alignment: .leading, spacing: 8) {
                if let pct {
                    HStack {
                        Text("Progreso hacia tu meta").font(.mCaption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(pct)%").font(.mCallout).foregroundStyle(Neon.accent)
                    }
                    ProgressView(value: progress.fraction ?? 0)
                        .tint(progress.achieved ? Neon.green : Neon.accent)
                }
                Text(caption).font(.mCaption2).foregroundStyle(.secondary)
            }

            // Stats: días restantes + confianza
            if goal.daysLeft() != nil || confidence != nil {
                HStack(spacing: 10) {
                    if let days = goal.daysLeft() {
                        GoalStatTile(label: "Faltan", value: "\(days)", unit: "días")
                    }
                    if let confidence {
                        GoalConfidenceTile(confidence: confidence)
                    }
                }
            }

            // Coach insight
            if let insight {
                CoachInsightView(text: insight)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Neon.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.06)))
    }
}

/// Casilla de dato (etiqueta + número héroe + unidad).
struct GoalStatTile: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.mCaption2).tracking(0.8).foregroundStyle(.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.marker(20))
                Text(unit).font(.mCaption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(Neon.surfaceElevated, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Casilla de confianza cualitativa (con color semántico + beacon).
struct GoalConfidenceTile: View {
    let confidence: GoalConfidence

    private var color: Color {
        switch confidence {
        case .achieved, .high: return Neon.green
        case .medium:          return Neon.gold
        case .low:             return Neon.orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CONFIANZA").font(.mCaption2).tracking(0.8).foregroundStyle(.tertiary)
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(confidence.label).font(.marker(18)).foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(Neon.surfaceElevated, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Bloque "Coach Insight" con la frase narrativa.
struct CoachInsightView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles").font(.mCaption).foregroundStyle(Neon.accent)
                Text("COACH INSIGHT").font(.mCaption2).tracking(1).foregroundStyle(Neon.accent)
            }
            Text(text).font(.mFootnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Neon.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Neon.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}
