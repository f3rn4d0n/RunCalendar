import SwiftUI

/// Lista de carreras del usuario, separadas en próximas y completadas.
struct RaceListView: View {
    @State var viewModel: RacesViewModel
    @State private var editingRace: Race?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.races.isEmpty {
                    EmptyStateView(
                        icon: "flag.checkered",
                        title: "Sin carreras",
                        message: "Agrega tu primera carrera con el botón +."
                    )
                } else {
                    List {
                        if !viewModel.upcomingRaces.isEmpty {
                            Section("Próximas") {
                                ForEach(viewModel.upcomingRaces) { race in
                                    NavigationLink { RaceDetailView(race: race, viewModel: viewModel) } label: {
                                        RaceRow(race: race)
                                    }
                                }
                            }
                        }
                        if !viewModel.completedRaces.isEmpty {
                            Section("Completadas") {
                                ForEach(viewModel.completedRaces) { race in
                                    NavigationLink { RaceDetailView(race: race, viewModel: viewModel) } label: {
                                        RaceRow(race: race)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Carreras")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $isCreating) {
                RaceFormView(viewModel: viewModel, race: nil)
            }
            .task { await viewModel.start() }
        }
    }
}

/// Fila compacta de una carrera.
struct RaceRow: View {
    let race: Race

    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Text(race.date.formatted(.dateTime.day()))
                    .font(.title3.bold())
                Text(race.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(race.name).font(.headline)
                Text("\(race.discipline.displayName) · \(race.location.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
