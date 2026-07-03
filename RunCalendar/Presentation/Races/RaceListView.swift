import SwiftUI

/// Criterio de orden de la lista de carreras.
enum RaceSort: String, CaseIterable, Identifiable {
    case date = "Fecha"
    case distance = "Distancia"
    case cost = "Costo"
    var id: String { rawValue }
}

/// Filtro por estado de inscripción.
enum RegistrationFilter: String, CaseIterable, Identifiable {
    case all = "Todas"
    case registered = "Inscritas"
    case notRegistered = "No inscritas"
    var id: String { rawValue }
}

/// Lista de carreras del usuario, separadas en próximas y completadas, con filtros y orden.
struct RaceListView: View {
    @State var viewModel: RacesViewModel
    @State private var isCreating = false

    // Filtros / orden
    @State private var sort: RaceSort = .date
    @State private var registrationFilter: RegistrationFilter = .all
    @State private var disciplineFilter: RaceDiscipline?
    @State private var onlyPriority = false

    private var hasActiveFilters: Bool {
        sort != .date || registrationFilter != .all || disciplineFilter != nil || onlyPriority
    }

    private var filteredRaces: [Race] {
        var result = viewModel.races
        if let disciplineFilter {
            result = result.filter { $0.discipline == disciplineFilter }
        }
        switch registrationFilter {
        case .all: break
        case .registered: result = result.filter(\.isRegistered)
        case .notRegistered: result = result.filter { !$0.isRegistered }
        }
        if onlyPriority {
            result = result.filter(\.isPriority)
        }
        return result.sorted(by: isBefore)
    }

    private func isBefore(_ lhs: Race, _ rhs: Race) -> Bool {
        switch sort {
        case .date: return lhs.date < rhs.date
        case .distance: return (lhs.distanceKm ?? 0) < (rhs.distanceKm ?? 0)
        case .cost: return (lhs.cost ?? 0) < (rhs.cost ?? 0)
        }
    }

    private var upcoming: [Race] { filteredRaces.filter { $0.status == .upcoming } }
    private var completed: [Race] { filteredRaces.filter { $0.status == .completed } }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.races.isEmpty {
                    EmptyStateView(
                        icon: "flag.checkered",
                        title: "Sin carreras",
                        message: "Agrega tu primera carrera con el botón +."
                    )
                } else if filteredRaces.isEmpty {
                    EmptyStateView(
                        icon: "line.3.horizontal.decrease.circle",
                        title: "Sin resultados",
                        message: "Ninguna carrera coincide con los filtros."
                    )
                } else {
                    List {
                        if !upcoming.isEmpty {
                            Section("Próximas") {
                                ForEach(upcoming) { race in
                                    NavigationLink { RaceDetailView(initialRace: race, viewModel: viewModel) } label: {
                                        RaceRow(race: race, sort: sort)
                                    }
                                }
                            }
                        }
                        if !completed.isEmpty {
                            Section("Completadas") {
                                ForEach(completed) { race in
                                    NavigationLink { RaceDetailView(initialRace: race, viewModel: viewModel) } label: {
                                        RaceRow(race: race, sort: sort)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Carreras")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { filterMenu }
                ToolbarItem(placement: .primaryAction) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Agregar carrera")
                }
            }
            .sheet(isPresented: $isCreating) {
                RaceFormView(viewModel: viewModel, race: nil)
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Ordenar por", selection: $sort) {
                ForEach(RaceSort.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Inscripción", selection: $registrationFilter) {
                ForEach(RegistrationFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Disciplina", selection: $disciplineFilter) {
                Text("Todas").tag(RaceDiscipline?.none)
                ForEach(RaceDiscipline.allCases) { Text($0.displayName).tag(Optional($0)) }
            }
            Toggle("Solo prioritarias", isOn: $onlyPriority)
        } label: {
            Image(systemName: hasActiveFilters
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filtros y orden")
    }
}

/// Fila compacta de una carrera.
struct RaceRow: View {
    let race: Race
    /// Criterio de orden activo, para resaltar el valor correspondiente.
    var sort: RaceSort = .date

    private var dateTileStyle: AnyShapeStyle {
        race.isPriority ? AnyShapeStyle(Neon.gold.opacity(0.18)) : AnyShapeStyle(.quaternary)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(race.date.formatted(.dateTime.day()))
                    .font(.title3.bold())
                Text(race.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 46, height: 46)
            .background(dateTileStyle, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if race.isPriority {
                        Image(systemName: "star.fill").font(.caption).foregroundStyle(Neon.gold)
                            .accessibilityLabel("Evento prioritario")
                    }
                    Text(race.name).font(.headline)
                }
                Text(race.location.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if sort == .cost, let cost = race.cost {
                    Text(cost.currencyString(code: race.currency))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                Text(race.discipline.displayName)
                    .font(.subheadline.weight(sort == .distance ? .semibold : .regular))
                    .foregroundStyle(sort == .distance ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                if race.isRegistered {
                    Text("Inscrito")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Neon.teal.opacity(0.2), in: Capsule())
                        .foregroundStyle(Neon.teal)
                }
                if let seconds = race.finishTimeSeconds {
                    Text(seconds.durationString())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
