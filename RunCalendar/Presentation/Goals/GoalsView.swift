import SwiftUI

/// Objetivos del atleta: lista de metas con su progreso. Fase 1 de la visión.
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
                            Button { editing = goal } label: {
                                GoalRow(goal: goal, progress: viewModel.progress(for: goal))
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(goal) }
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
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

/// Fila de una meta con barra de progreso y "actual vs. faltan".
struct GoalRow: View {
    let goal: Goal
    let progress: GoalProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(goal.title, systemImage: goal.type.systemImage).font(.mHeadline)
                Spacer()
                if progress.achieved {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Neon.green)
                        .accessibilityLabel("Logrado")
                }
            }
            if let fraction = progress.fraction {
                ProgressView(value: fraction)
                    .tint(progress.achieved ? Neon.green : Neon.accent)
            }
            HStack {
                Text("Actual: \(progress.currentText)")
                    .font(.mCaption).foregroundStyle(.secondary)
                Spacer()
                Text(progress.deltaText)
                    .font(.mCaption.weight(.semibold))
                    .foregroundStyle(progress.achieved ? Neon.green : .secondary)
            }
            if let deadline = goal.deadline {
                Text("Meta para \(deadline.mediumString())")
                    .font(.mCaption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
