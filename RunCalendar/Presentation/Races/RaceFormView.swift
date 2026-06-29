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
            status: status
        )

        if await viewModel.save(newRace, isNew: isNew) {
            dismiss()
        }
    }
}
