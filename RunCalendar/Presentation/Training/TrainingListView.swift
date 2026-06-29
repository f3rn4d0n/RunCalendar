import SwiftUI

/// Lista de entrenamientos, filtrable por tipo (CrossFit / Carrera).
struct TrainingListView: View {
    @State var viewModel: TrainingViewModel
    @State private var filter: TrainingType?
    @State private var isCreating = false

    private var filtered: [TrainingSession] {
        guard let filter else { return viewModel.sessions }
        return viewModel.sessions(of: filter)
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
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Filtro", selection: $filter) {
                            Text("Todos").tag(TrainingType?.none)
                            ForEach(TrainingType.allCases) { Text($0.displayName).tag(Optional($0)) }
                        }
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }
            }
            .sheet(isPresented: $isCreating) {
                TrainingFormView(viewModel: viewModel, session: nil)
            }
            .task { await viewModel.start() }
        }
    }
}

/// Fila compacta de un entrenamiento.
struct TrainingRow: View {
    let session: TrainingSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.type.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title).font(.headline)
                Text(session.date.mediumString())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if session.completed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}
