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
            Section {
                chipsRow
            }
            .listRowBackground(Color.clear)

            Section("Evento") {
                row("Fecha", race.date.dateTimeString(), icon: "calendar")
                row("Disciplina", race.discipline.displayName, icon: "figure.run")
                if let distance = race.distanceKm {
                    row("Distancia", "\(distance.formatted()) km", icon: "ruler")
                }
            }

            Section("Ubicación") {
                row("Lugar", race.location.name, icon: "mappin.and.ellipse")
                if !race.location.address.isEmpty {
                    row("Dirección", race.location.address, icon: "map")
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
                 color: race.status == .completed ? .green : .blue)
            if race.isRegistered {
                chip("Inscrito", systemImage: "person.badge.checkmark", color: .green)
            }
            if race.isPriority {
                chip("Prioritario", systemImage: "star.fill", color: .yellow)
            }
            Spacer()
        }
    }

    private func chip(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
