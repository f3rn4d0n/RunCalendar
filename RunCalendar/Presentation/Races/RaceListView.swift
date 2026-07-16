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
    let trainingViewModel: TrainingViewModel
    @State private var isCreating = false
    @State private var showingRecords = false

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

    @ViewBuilder
    private func raceLink(_ race: Race) -> some View {
        NavigationLink {
            RaceDetailView(initialRace: race, viewModel: viewModel, trainingViewModel: trainingViewModel)
        } label: {
            RaceRow(race: race, sort: sort)
        }
    }

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
                        if let spending = viewModel.spendingThisYear {
                            Section {
                                NavigationLink {
                                    SpendingDetailView(spending: spending)
                                } label: {
                                    SpendingSummaryCard(spending: spending)
                                }
                            }
                        }
                        if !upcoming.isEmpty {
                            Section("Próximas") {
                                ForEach(upcoming) { race in
                                    raceLink(race)
                                }
                            }
                        }
                        if !completed.isEmpty {
                            Section("Completadas") {
                                ForEach(completed) { race in
                                    raceLink(race)
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
                    Button { showingRecords = true } label: { Image(systemName: "medal") }
                        .accessibilityLabel("Récords personales")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isCreating = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Agregar carrera")
                }
            }
            .sheet(isPresented: $isCreating) {
                RaceFormView(viewModel: viewModel, race: nil)
            }
            .sheet(isPresented: $showingRecords) {
                PersonalRecordsView(racesViewModel: viewModel, trainingViewModel: trainingViewModel)
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

/// Tarjeta con el gasto en carreras del año en curso.
private struct SpendingSummaryCard: View {
    let spending: SpendingSummary

    private var amountsText: String {
        spending.totals
            .map { $0.amount.currencyString(code: $0.currency) }
            .joined(separator: " + ")
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "creditcard.fill")
                .font(.mTitle3)
                .foregroundStyle(Neon.teal)
                .frame(width: 44, height: 44)
                .background(Neon.teal.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(amountsText).font(.mTitle3.bold())
                Text("en \(spending.count) \(spending.count == 1 ? "carrera inscrita" : "carreras inscritas") de \(String(spending.year))")
                    .font(.mSubheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Detalle de gastos del año: total y desglose por mes con las carreras.
private struct SpendingDetailView: View {
    let spending: SpendingSummary

    private func amounts(_ totals: [CurrencyTotal]) -> String {
        totals.map { $0.amount.currencyString(code: $0.currency) }.joined(separator: " + ")
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total \(String(spending.year))").font(.mHeadline)
                    Spacer()
                    Text(amounts(spending.totals))
                        .font(.mHeadline).foregroundStyle(Neon.teal)
                }
            }

            ForEach(spending.months) { month in
                Section {
                    ForEach(month.races) { race in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(race.name).font(.mSubheadline)
                                Text(race.date.mediumString())
                                    .font(.mCaption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let cost = race.cost {
                                Text(cost.currencyString(code: race.currency))
                                    .font(.mSubheadline.monospacedDigit())
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(month.name)
                        Spacer()
                        Text(amounts(month.totals)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Gastos \(String(spending.year))")
        .navigationBarTitleDisplayMode(.inline)
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
                    .font(.mTitle3.bold())
                Text(race.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.mCaption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 46, height: 46)
            .background(dateTileStyle, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if race.isPriority {
                        Image(systemName: "star.fill").font(.mCaption).foregroundStyle(Neon.gold)
                            .accessibilityLabel("Evento prioritario")
                    }
                    Text(race.name).font(.mHeadline)
                }
                Text(race.location.name)
                    .font(.mSubheadline)
                    .foregroundStyle(.secondary)
                if race.status == .upcoming, race.date.daysFromNow() >= 0 {
                    Text(race.date.countdownText())
                        .font(.mCaption2.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if sort == .cost, let cost = race.cost {
                    Text(cost.currencyString(code: race.currency))
                        .font(.mSubheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                Text(race.discipline.displayName)
                    .font(.mSubheadline.weight(sort == .distance ? .semibold : .regular))
                    .foregroundStyle(sort == .distance ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                if race.isRegistered {
                    Text("Inscrito")
                        .font(.mCaption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Neon.teal.opacity(0.2), in: Capsule())
                        .foregroundStyle(Neon.teal)
                }
                if let seconds = race.finishTimeSeconds {
                    Text(seconds.durationString())
                        .font(.mCaption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
