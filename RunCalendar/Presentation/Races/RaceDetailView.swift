import SwiftUI

/// Detalle de una carrera con toda su información.
struct RaceDetailView: View {
    /// Copia recibida al navegar; se usa como id y como respaldo.
    let initialRace: Race
    @State var viewModel: RacesViewModel

    @State private var isEditing = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    /// Versión viva de la carrera desde el ViewModel: refleja ediciones en tiempo real.
    /// Si ya no existe (p. ej. fue eliminada), cae al respaldo recibido.
    private var race: Race {
        viewModel.races.first { $0.id == initialRace.id } ?? initialRace
    }

    var body: some View {
        List {
            Section("Evento") {
                row("Fecha", race.date.dateTimeString())
                row("Disciplina", race.discipline.displayName)
                if let distance = race.distanceKm {
                    row("Distancia", "\(distance.formatted()) km")
                }
                row("Estado", race.status.displayName)
                if race.isPriority {
                    HStack {
                        Label("Evento prioritario", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                        Spacer()
                    }
                }
            }

            Section("Ubicación") {
                row("Lugar", race.location.name)
                if !race.location.address.isEmpty {
                    row("Dirección", race.location.address)
                }
            }

            if race.cost != nil || race.registrationURL != nil {
                Section("Costo e inscripción") {
                    if let cost = race.cost {
                        row("Costo", cost.currencyString(code: race.currency))
                    }
                    if let url = race.registrationURL {
                        Link(destination: url) {
                            Label("Inscripción", systemImage: "link")
                        }
                    }
                }
            }

            Section("Inscripción") {
                row("Estatus", race.isRegistered ? "Inscrito" : "No inscrito")
                if let bib = race.bibNumber {
                    row("Número de corredor", bib)
                }
            }

            if let seconds = race.finishTimeSeconds {
                Section("Resultado") {
                    row("Tiempo", seconds.durationString())
                }
            }

            if let kit = race.kitPickup {
                Section("Entrega de kit") {
                    if let date = kit.date { row("Fecha", date.dateTimeString()) }
                    if let location = kit.location { row("Lugar", location.name) }
                    if !kit.notes.isEmpty { row("Notas", kit.notes) }
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
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}
