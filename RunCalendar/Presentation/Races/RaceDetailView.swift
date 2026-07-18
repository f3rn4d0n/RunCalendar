import SwiftUI

/// Detalle de una carrera con toda su información.
struct RaceDetailView: View {
    /// Copia recibida al navegar; se usa como id y como respaldo.
    let initialRace: Race
    @State var viewModel: RacesViewModel
    let trainingViewModel: TrainingViewModel
    let healthViewModel: HealthViewModel

    @State private var isEditing = false
    @State private var showDeleteAlert = false
    @State private var calendarMessage: String?
    @Environment(\.dismiss) private var dismiss

    /// Versión viva de la carrera desde el ViewModel: refleja ediciones en tiempo real.
    /// Si ya no existe (p. ej. fue eliminada), cae al respaldo recibido.
    private var race: Race {
        viewModel.races.first { $0.id == initialRace.id } ?? initialRace
    }

    /// Entrenamientos que apuntan a este evento, ordenados por fecha.
    private var linkedTrainings: [TrainingSession] {
        let matches = trainingViewModel.sessions.filter { $0.targetRaceID == race.id }
        return matches.sorted { $0.date < $1.date }
    }

    private var completedTrainingCount: Int {
        linkedTrainings.filter(\.completed).count
    }

    private static let standardDistances: [RaceDiscipline] = [.fiveK, .tenK, .fifteenK, .halfMarathon, .marathon]

    /// Muestra la preparación solo para carreras próximas de distancia estándar.
    private var showsReadiness: Bool {
        healthViewModel.isHealthAvailable
            && race.date.daysFromNow() >= 0
            && Self.standardDistances.contains(race.discipline)
    }

    private var raceReadiness: RaceReadiness? {
        healthViewModel.readinessByDistance.first { $0.distance == race.discipline }
    }

    @ViewBuilder
    private var readinessSection: some View {
        if showsReadiness {
            Section {
                if let readiness = raceReadiness {
                    NavigationLink {
                        ReadinessDetailView(readiness: readiness)
                    } label: {
                        RaceReadinessRow(race: race, readiness: readiness)
                    }
                } else {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Calculando con tus datos de Salud…").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Tu preparación")
            } footer: {
                Text("Toca para ver qué mejorar antes de esta carrera.")
            }
        }
    }

    var body: some View {
        List {
            Section {
                if race.date.daysFromNow() >= 0 {
                    VStack(spacing: 2) {
                        Text(race.date.countdownText())
                            .font(.mLargeTitle.bold())
                            .foregroundStyle(.tint)
                        Text(race.date.mediumString())
                            .font(.mSubheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
                }
                chipsRow
            }
            .listRowBackground(Color.clear)

            Section("Evento") {
                row("Fecha", race.date.dateTimeString(), icon: "calendar")
                row("Disciplina", race.discipline.displayName, icon: "figure.run")
                if let distance = race.distanceKm {
                    row("Distancia", "\(distance.formatted()) km", icon: "ruler")
                }
                Button {
                    Task {
                        calendarMessage = await viewModel.addRaceToCalendar(race)
                            ? "Se agregó la carrera a tu calendario."
                            : "No se pudo agregar. Revisa el permiso de Calendario en Ajustes."
                    }
                } label: {
                    Label("Añadir al calendario", systemImage: "calendar.badge.plus")
                }
            }

            readinessSection

            Section("Ubicación") {
                row("Lugar", race.location.name, icon: "mappin.and.ellipse")
                if !race.location.address.isEmpty {
                    row("Dirección", race.location.address, icon: "map")
                }
                if let coordinate = race.location.coordinate {
                    NavigateButton(coordinate: coordinate)
                }
            }

            if race.location.latitude != nil || !race.location.name.isEmpty || !race.location.address.isEmpty {
                Section("Clima") {
                    WeatherCardView { await viewModel.weather(for: race) }
                }
            }

            if race.cost != nil || race.registrationURL != nil {
                Section("Costo e inscripción") {
                    if let cost = race.cost {
                        row("Costo", cost.currencyString(code: race.currency), icon: "creditcard")
                    }
                    if let url = race.registrationURL {
                        Link(destination: url) {
                            Label("Inscripción", systemImage: "link")
                        }
                    }
                }
            }

            Section("Inscripción") {
                row("Estatus", race.isRegistered ? "Inscrito" : "No inscrito",
                    icon: "person.badge.checkmark")
                if let bib = race.bibNumber {
                    row("Número de corredor", bib, icon: "number")
                }
            }

            if let seconds = race.finishTimeSeconds {
                Section("Resultado") {
                    row("Tiempo", seconds.durationString(), icon: "stopwatch")
                }
            }

            if race.status == .completed, trainingViewModel.canShowRoutes {
                Section("Recorrido") {
                    NavigationLink {
                        WorkoutRouteMapView(
                            title: race.name,
                            date: race.date,
                            distanceKm: race.distanceKm,
                            loader: trainingViewModel.route,
                            isAvailable: trainingViewModel.canShowRoutes
                        )
                    } label: {
                        Label("Ver ruta en el mapa", systemImage: "map")
                    }
                }
            }

            if !linkedTrainings.isEmpty {
                Section("Entrenamientos para este evento") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(completedTrainingCount) de \(linkedTrainings.count) completados")
                            .font(.mSubheadline)
                        ProgressView(
                            value: Double(completedTrainingCount),
                            total: Double(linkedTrainings.count)
                        )
                        .tint(Neon.green)
                    }
                    ForEach(linkedTrainings) { training in
                        HStack(spacing: 12) {
                            Image(systemName: training.type.systemImage)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(training.title)
                                Text(training.date.mediumString())
                                    .font(.mCaption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if training.completed {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Neon.green)
                            }
                        }
                    }
                }
            }

            if let kit = race.kitPickup {
                Section("Entrega de kit") {
                    if let date = kit.date { row("Fecha", date.dateTimeString()) }
                    if let location = kit.location { row("Lugar", location.name) }
                    if !kit.notes.isEmpty { row("Notas", kit.notes) }
                    if let coordinate = kit.location?.coordinate {
                        NavigateButton(coordinate: coordinate, label: "Cómo llegar a la entrega")
                    }
                    if kit.date != nil {
                        Button {
                            Task {
                                calendarMessage = await viewModel.addKitPickupToCalendar(race)
                                    ? "Se agregó la entrega de kit a tu calendario."
                                    : "No se pudo agregar. Revisa el permiso de Calendario en Ajustes."
                            }
                        } label: {
                            Label("Añadir la entrega al calendario", systemImage: "calendar.badge.plus")
                        }
                    }
                }
            }

            if !race.notes.isEmpty {
                Section("Notas") { Text(race.notes) }
            }

            Section {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Eliminar carrera", systemImage: "trash")
                }
            }
        }
        .navigationTitle(race.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Carga la readiness si aún no está (idempotente: no re-pide permiso si ya se dio).
            if showsReadiness { await healthViewModel.onAppear() }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            RaceFormView(viewModel: viewModel, race: race)
        }
        .alert("¿Eliminar carrera?", isPresented: $showDeleteAlert) {
            Button("Eliminar", role: .destructive) {
                Task {
                    await viewModel.delete(race)
                    dismiss()
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("Calendario", isPresented: Binding(
            get: { calendarMessage != nil },
            set: { if !$0 { calendarMessage = nil } }
        )) {
            Button("OK") { calendarMessage = nil }
        } message: {
            Text(calendarMessage ?? "")
        }
    }

    private func row(_ label: String, _ value: String, icon: String? = nil) -> some View {
        HStack {
            if let icon {
                Label(label, systemImage: icon).foregroundStyle(.secondary)
            } else {
                Text(label).foregroundStyle(.secondary)
            }
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    /// Chips de estado en la cabecera del detalle.
    private var chipsRow: some View {
        HStack(spacing: 8) {
            chip(race.status.displayName,
                 systemImage: race.status == .completed ? "checkmark.circle.fill" : "clock",
                 color: race.status == .completed ? Neon.green : Neon.accent)
            if race.isRegistered {
                chip("Inscrito", systemImage: "person.badge.checkmark", color: Neon.teal)
            }
            if race.isPriority {
                chip("Prioritario", systemImage: "star.fill", color: Neon.gold)
            }
            Spacer()
        }
    }

    private func chip(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.mCaption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
