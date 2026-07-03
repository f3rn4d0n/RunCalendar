import SwiftUI

/// Formulario de alta/edición de una carrera.
struct RaceFormView: View {
    @State var viewModel: RacesViewModel
    let race: Race?

    @Environment(\.dismiss) private var dismiss

    // Campos del formulario
    @State private var name = ""
    @State private var date = Date()
    @State private var discipline: RaceDiscipline = .tenK
    @State private var distanceText = ""
    @State private var locationName = ""
    @State private var locationAddress = ""
    @State private var costText = ""
    @State private var currency = "MXN"
    @State private var registrationURLText = ""
    @State private var status: RaceStatus = .upcoming
    @State private var notes = ""
    @State private var isPriority = false

    // Inscripción
    @State private var isRegistered = false
    @State private var bibNumber = ""

    // Resultado (tiempo)
    @State private var finishHours = ""
    @State private var finishMinutes = ""
    @State private var finishSeconds = ""

    // Kit
    @State private var hasKit = false
    @State private var kitDate = Date()
    @State private var kitLocation = ""
    @State private var kitNotes = ""

    private var isNew: Bool { race == nil }
    private var title: String { isNew ? "Nueva carrera" : "Editar carrera" }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos") {
                    TextField("Nombre", text: $name)
                    DatePicker("Fecha", selection: $date)
                    Picker("Disciplina", selection: $discipline) {
                        ForEach(RaceDiscipline.allCases) { Text($0.displayName).tag($0) }
                    }
                    TextField("Distancia (km)", text: $distanceText)
                        .keyboardType(.decimalPad)
                    Picker("Estado", selection: $status) {
                        ForEach(RaceStatus.allCases) { Text($0.displayName).tag($0) }
                    }
                    Toggle(isOn: $isPriority) {
                        Label("Evento prioritario", systemImage: "star.fill")
                    }
                }

                Section("Ubicación") {
                    TextField("Lugar", text: $locationName)
                    TextField("Dirección", text: $locationAddress)
                }

                Section("Costo e inscripción") {
                    HStack {
                        TextField("Costo", text: $costText).keyboardType(.decimalPad)
                        TextField("Moneda", text: $currency).frame(width: 70)
                    }
                    TextField("URL de inscripción", text: $registrationURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Inscripción") {
                    Toggle("Ya estoy inscrito", isOn: $isRegistered)
                    if isRegistered {
                        TextField("Número de corredor (dorsal)", text: $bibNumber)
                    }
                }

                if status == .completed {
                    Section("Resultado") {
                        HStack(spacing: 12) {
                            timeField("Horas", $finishHours)
                            Text(":").foregroundStyle(.secondary)
                            timeField("Min", $finishMinutes)
                            Text(":").foregroundStyle(.secondary)
                            timeField("Seg", $finishSeconds)
                        }
                    }
                }

                Section("Entrega de kit") {
                    Toggle("Tiene entrega de kit", isOn: $hasKit)
                    if hasKit {
                        DatePicker("Fecha del kit", selection: $kitDate)
                        TextField("Lugar del kit", text: $kitLocation)
                        TextField("Notas del kit", text: $kitNotes)
                    }
                }

                Section("Notas") {
                    TextField("Notas", text: $notes, axis: .vertical).lineLimit(3...6)
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func timeField(_ label: String, _ text: Binding<String>) -> some View {
        VStack(spacing: 2) {
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func populate() {
        guard let race else { return }
        name = race.name
        date = race.date
        discipline = race.discipline
        distanceText = race.distanceKm.map { String($0) } ?? ""
        locationName = race.location.name
        locationAddress = race.location.address
        costText = race.cost.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        currency = race.currency
        registrationURLText = race.registrationURL?.absoluteString ?? ""
        status = race.status
        notes = race.notes
        isPriority = race.isPriority
        isRegistered = race.isRegistered
        bibNumber = race.bibNumber ?? ""
        if let secs = race.finishTimeSeconds {
            finishHours = String(secs / 3600)
            finishMinutes = String((secs % 3600) / 60)
            finishSeconds = String(secs % 60)
        }
        if let kit = race.kitPickup {
            hasKit = true
            kitDate = kit.date ?? race.date
            kitLocation = kit.location?.name ?? ""
            kitNotes = kit.notes
        }
    }

    private func save() async {
        let kit: KitPickup? = hasKit
            ? KitPickup(
                date: kitDate,
                location: kitLocation.isEmpty ? nil : RaceLocation(name: kitLocation),
                notes: kitNotes
            )
            : nil

        let trimmedBib = bibNumber.trimmingCharacters(in: .whitespaces)
        let bib: String? = isRegistered && !trimmedBib.isEmpty ? trimmedBib : nil

        let hours = Int(finishHours) ?? 0
        let minutes = Int(finishMinutes) ?? 0
        let seconds = Int(finishSeconds) ?? 0
        let totalSeconds = hours * 3600 + minutes * 60 + seconds
        let finishTime: Int? = status == .completed && totalSeconds > 0 ? totalSeconds : nil

        let newRace = Race(
            id: race?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            date: date,
            discipline: discipline,
            distanceKm: Double(distanceText.replacingOccurrences(of: ",", with: ".")),
            location: RaceLocation(name: locationName, address: locationAddress),
            cost: Decimal(string: costText.replacingOccurrences(of: ",", with: ".")),
            currency: currency.isEmpty ? "MXN" : currency,
            registrationURL: URL(string: registrationURLText),
            kitPickup: kit,
            notes: notes,
            status: status,
            isRegistered: isRegistered,
            bibNumber: bib,
            finishTimeSeconds: finishTime,
            isPriority: isPriority
        )

        if await viewModel.save(newRace, isNew: isNew) {
            dismiss()
        }
    }
}
