import SwiftUI

/// Detalle de solo lectura de un entrenamiento. Cada dato sale rotulado (con unidades)
/// para que se entienda qué significa cada número. "Editar" abre el formulario.
struct TrainingDetailView: View {
    let initialSession: TrainingSession
    @State var viewModel: TrainingViewModel
    let racesViewModel: RacesViewModel

    @State private var isEditing = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    /// Versión viva desde el ViewModel: refleja ediciones al instante; si ya no existe, usa el respaldo.
    private var session: TrainingSession {
        viewModel.sessions.first { $0.id == initialSession.id } ?? initialSession
    }

    private var targetRaceName: String? {
        session.targetRaceID.flatMap { id in racesViewModel.races.first { $0.id == id }?.name }
    }

    /// Ritmo promedio "m:ss" derivado de la distancia y la duración registradas.
    private var avgPace: String? {
        guard let km = session.distanceKm, km > 0, let min = session.durationMin, min > 0 else { return nil }
        let secondsPerKm = Int(Double(min * 60) / km)
        return String(format: "%d:%02d", secondsPerKm / 60, secondsPerKm % 60)
    }

    var body: some View {
        List {
            Section {
                chipsRow
            }
            .listRowBackground(Color.clear)

            Section("Entrenamiento") {
                row("Tipo", session.type.displayName, icon: session.type.systemImage)
                row("Fecha", session.date.dateTimeString(), icon: "calendar")
                if let min = session.durationMin {
                    row("Duración", "\(min) min", icon: "clock")
                }
                row("Estado", session.completed ? "Completado" : "Pendiente",
                    icon: session.completed ? "checkmark.circle" : "circle")
            }

            if session.type == .running {
                Section("Carrera") {
                    if let distance = session.distanceKm {
                        row("Distancia", "\(distance.formatted()) km", icon: "ruler")
                    }
                    if let pace = avgPace {
                        row("Ritmo promedio", "\(pace) /km", icon: "speedometer")
                    }
                    if let hr = session.avgHeartRate {
                        row("FC promedio", "\(hr) lpm", icon: "heart.fill")
                    }
                    if let pace = session.targetPace, !pace.isEmpty {
                        row("Ritmo objetivo", pace, icon: "target")
                    }
                }
                if viewModel.canShowRoutes {
                    Section("Recorrido") {
                        NavigationLink {
                            WorkoutRouteMapView(
                                title: session.title,
                                date: session.date,
                                distanceKm: session.distanceKm,
                                loader: viewModel.route,
                                isAvailable: viewModel.canShowRoutes
                            )
                        } label: {
                            Label("Ver ruta en el mapa", systemImage: "map")
                        }
                    }

                    Section("Clima") {
                        WeatherCardView(
                            emptyMessage: "Sin ubicación GPS para consultar el clima de este entrenamiento."
                        ) { await viewModel.weather(for: session) }
                    }
                }
            } else if let wod = session.wod, !wod.isEmpty {
                Section("WOD") { Text(wod) }
            }

            if let targetRaceName {
                Section("Evento objetivo") {
                    row("Para el evento", targetRaceName, icon: "target")
                }
            }

            if !session.details.isEmpty {
                Section("Descripción") { Text(session.details) }
            }

            if !session.notes.isEmpty {
                Section("Notas") { Text(session.notes) }
            }

            Section {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Eliminar entrenamiento", systemImage: "trash")
                }
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            TrainingFormView(viewModel: viewModel, racesViewModel: racesViewModel, session: session)
        }
        .alert("¿Eliminar entrenamiento?", isPresented: $showDeleteAlert) {
            Button("Eliminar", role: .destructive) {
                Task {
                    await viewModel.delete(session)
                    dismiss()
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var chipsRow: some View {
        HStack(spacing: 8) {
            chip(session.type.displayName, systemImage: session.type.systemImage, color: Neon.accent)
            if session.completed {
                chip("Completado", systemImage: "checkmark.circle.fill", color: Neon.green)
            }
            if session.isPriority {
                chip("Prioritario", systemImage: "star.fill", color: Neon.gold)
            }
            Spacer()
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

    private func chip(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.mCaption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
