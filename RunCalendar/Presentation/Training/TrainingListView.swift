import SwiftUI

/// Lista de entrenamientos, filtrable por tipo (CrossFit / Carrera).
struct TrainingListView: View {
    @State var viewModel: TrainingViewModel
    @State private var filter: TrainingType?
    @State private var onlyPriority = false
    @State private var isCreating = false

    private var filtered: [TrainingSession] {
        var result = filter.map(viewModel.sessions(of:)) ?? viewModel.sessions
        if onlyPriority { result = result.filter(\.isPriority) }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessions.isEmpty {
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "Sin entrenamientos",
                        message: "Agrega tu primer entrenamiento con el botón +."
                    )
                } else {
                    List {
                        ForEach(filtered) { session in
                            NavigationLink {
                                TrainingFormView(viewModel: viewModel, session: session)
                            } label: {
                                TrainingRow(session: session)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(session) }
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                Button {
                                    Task { await viewModel.toggleCompleted(session) }
                                } label: {
                                    Label("Hecho", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Entrenamiento")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Agregar entrenamiento")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Filtro", selection: $filter) {
                            Text("Todos").tag(TrainingType?.none)
                            ForEach(TrainingType.allCases) { Text($0.displayName).tag(Optional($0)) }
                        }
                        Toggle("Solo prioritarios", isOn: $onlyPriority)
                    } label: {
                        Image(systemName: filter != nil || onlyPriority
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filtros")
                }
            }
            .sheet(isPresented: $isCreating) {
                TrainingFormView(viewModel: viewModel, session: nil)
            }
        }
    }
}

/// Fila compacta de un entrenamiento.
struct TrainingRow: View {
    let session: TrainingSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.type.systemImage)
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if session.isPriority {
                        Image(systemName: "star.fill").font(.caption).foregroundStyle(Neon.gold)
                            .accessibilityLabel("Prioritario")
                    }
                    Text(session.title).font(.headline)
                }
                Text(session.date.mediumString())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: session.completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(session.completed ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                .contentTransition(.symbolEffect(.replace))
                .animation(.smooth, value: session.completed)
                .accessibilityLabel(session.completed ? "Completado" : "Sin completar")
        }
        .padding(.vertical, 2)
    }
}
