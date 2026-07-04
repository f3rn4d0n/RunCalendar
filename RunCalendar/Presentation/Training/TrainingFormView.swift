import SwiftUI

/// Formulario de alta/edición de un entrenamiento (CrossFit o carrera).
struct TrainingFormView: View {
    @State var viewModel: TrainingViewModel
    let racesViewModel: RacesViewModel
    let session: TrainingSession?

    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var type: TrainingType = .running
    @State private var trainingTitle = ""
    @State private var details = ""
    @State private var durationText = ""
    @State private var distanceText = ""
    @State private var targetPace = ""
    @State private var wod = ""
    @State private var completed = false
    @State private var notes = ""
    @State private var isPriority = false
    @State private var targetRaceID: String?

    private var isNew: Bool { session == nil }

    /// Carreras seleccionables como objetivo, prioritarias primero y luego por fecha.
    private var targetableRaces: [Race] {
        racesViewModel.races.sorted {
            if $0.isPriority != $1.isPriority { return $0.isPriority }
            return $0.date < $1.date
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    Picker("Tipo", selection: $type) {
                        ForEach(TrainingType.allCases) {
                            Label($0.displayName, systemImage: $0.systemImage).tag($0)
                        }
                    }
                    TextField("Título", text: $trainingTitle)
                    DatePicker("Fecha", selection: $date)
                    TextField("Duración (min)", text: $durationText)
                        .keyboardType(.numberPad)
                    Toggle("Completado", isOn: $completed)
                    Toggle(isOn: $isPriority) {
                        Label("Prioritario", systemImage: "star.fill")
                    }
                }

                if !targetableRaces.isEmpty {
                    Section("Evento objetivo") {
                        Picker("Para el evento", selection: $targetRaceID) {
                            Text("Ninguno").tag(String?.none)
                            ForEach(targetableRaces) { race in
                                Text(race.name).tag(Optional(race.id))
                            }
                        }
                    }
                }

                if type == .running {
                    Section("Carrera") {
                        TextField("Distancia (km)", text: $distanceText)
                            .keyboardType(.decimalPad)
                        TextField("Ritmo objetivo (p. ej. 5:30 min/km)", text: $targetPace)
                    }
                } else {
                    Section("CrossFit") {
                        TextField("WOD", text: $wod, axis: .vertical).lineLimit(2...6)
                    }
                }

                Section("Descripción") {
                    TextField("Detalles", text: $details, axis: .vertical).lineLimit(2...6)
                }

                Section("Notas") {
                    TextField("Notas", text: $notes, axis: .vertical).lineLimit(2...4)
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.mFootnote) }
                }
            }
            .navigationTitle(isNew ? "Nuevo entrenamiento" : "Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(trainingTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        guard let session else { return }
        date = session.date
        type = session.type
        trainingTitle = session.title
        details = session.details
        durationText = session.durationMin.map(String.init) ?? ""
        distanceText = session.distanceKm.map { String($0) } ?? ""
        targetPace = session.targetPace ?? ""
        wod = session.wod ?? ""
        completed = session.completed
        notes = session.notes
        isPriority = session.isPriority
        targetRaceID = session.targetRaceID
    }

    private func save() async {
        let newSession = TrainingSession(
            id: session?.id ?? UUID().uuidString,
            date: date,
            type: type,
            title: trainingTitle.trimmingCharacters(in: .whitespaces),
            details: details,
            durationMin: Int(durationText),
            distanceKm: type == .running
                ? Double(distanceText.replacingOccurrences(of: ",", with: "."))
                : nil,
            targetPace: type == .running && !targetPace.isEmpty ? targetPace : nil,
            wod: type == .crossfit && !wod.isEmpty ? wod : nil,
            completed: completed,
            notes: notes,
            isPriority: isPriority,
            targetRaceID: targetRaceID
        )

        if await viewModel.save(newSession, isNew: isNew) {
            dismiss()
        }
    }
}
