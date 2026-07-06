import SwiftUI

/// Lista de entrenamientos, filtrable por tipo (CrossFit / Carrera).
struct TrainingListView: View {
    @State var viewModel: TrainingViewModel
    let racesViewModel: RacesViewModel
    @State private var filter: TrainingType?
    @State private var onlyPriority = false
    @State private var isCreating = false
    @State private var isImporting = false

    private var filtered: [TrainingSession] {
        var result = filter.map(viewModel.sessions(of:)) ?? viewModel.sessions
        if onlyPriority { result = result.filter(\.isPriority) }
        return result
    }

    private var racesByID: [String: Race] {
        Dictionary(racesViewModel.races.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func targetName(for session: TrainingSession) -> String? {
        session.targetRaceID.flatMap { racesByID[$0]?.name }
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
                                TrainingFormView(viewModel: viewModel, racesViewModel: racesViewModel, session: session)
                            } label: {
                                TrainingRow(session: session, targetName: targetName(for: session))
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
                if !viewModel.importableWorkouts.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button { isImporting = true } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .accessibilityLabel("Importar de Salud")
                    }
                }
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
                TrainingFormView(viewModel: viewModel, racesViewModel: racesViewModel, session: nil)
            }
            .sheet(isPresented: $isImporting) {
                ImportWorkoutsView(viewModel: viewModel)
            }
            .task { await viewModel.loadRecentWorkouts() }
        }
    }
}

/// Hoja para importar carreras de Apple Salud aún no registradas.
private struct ImportWorkoutsView: View {
    @State var viewModel: TrainingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.importableWorkouts.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "Todo al día",
                        message: "No hay carreras nuevas en Salud por importar."
                    )
                } else {
                    List(viewModel.importableWorkouts) { workout in
                        HStack(spacing: 12) {
                            Image(systemName: "figure.run")
                                .foregroundStyle(.tint).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(workout.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                                    .font(.mHeadline)
                                Text(workout.date.mediumString())
                                    .font(.mCaption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Importar") { Task { await viewModel.importWorkout(workout) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Desde Apple Salud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

/// Fila compacta de un entrenamiento.
struct TrainingRow: View {
    let session: TrainingSession
    var targetName: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.type.systemImage)
                .font(.mHeadline)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if session.isPriority {
                        Image(systemName: "star.fill").font(.mCaption).foregroundStyle(Neon.gold)
                            .accessibilityLabel("Prioritario")
                    }
                    Text(session.title).font(.mHeadline)
                }
                Text(session.date.mediumString())
                    .font(.mSubheadline)
                    .foregroundStyle(.secondary)
                if let targetName {
                    Label(targetName, systemImage: "target")
                        .font(.mCaption2)
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                }
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
