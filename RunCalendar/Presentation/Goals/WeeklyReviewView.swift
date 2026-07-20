import SwiftUI

/// Review dominical (Fase 2): peso · cintura · energía · hambre.
/// Las medidas van a **Salud**; lo subjetivo, a Firestore (`bodyLogs`).
struct WeeklyReviewView: View {
    @State var viewModel: GoalsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var weightText = ""
    @State private var waistText = ""
    @State private var energy = 3
    @State private var hunger = 3
    @State private var notes = ""
    @State private var date = Date()

    /// Valor válido, o `nil` si está vacío o fuera de rango.
    private func parsed(_ text: String, as measure: BodyMeasure) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return measure.isValid(value) ? value : nil
    }

    /// Un campo con texto que no parsea o queda fuera de rango bloquea el guardado:
    /// más vale no registrar que meter basura en Salud.
    private func isBlocking(_ text: String, as measure: BodyMeasure) -> Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && parsed(text, as: measure) == nil
    }

    private var canSave: Bool {
        !isBlocking(weightText, as: .weight) && !isBlocking(waistText, as: .waist)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fecha", selection: $date, in: ...Date(), displayedComponents: .date)
                } footer: {
                    Text("El review es semanal, idealmente el domingo. Puedes dejar en blanco "
                        + "lo que no midas hoy.")
                }

                Section("Medidas") {
                    LabeledContent("Peso") {
                        TextField(placeholder(.weight), text: $weightText)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Cintura") {
                        TextField(placeholder(.waist), text: $waistText)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    scale("Energía", value: $energy, label: BodyLog.energyLabel)
                    scale("Hambre", value: $hunger, label: BodyLog.hungerLabel)
                } header: {
                    Text("Cómo te sentiste")
                } footer: {
                    Text("Energía y hambre no están en Salud, pero explican por qué una semana "
                        + "salió como salió.")
                }

                Section("Notas") {
                    TextField("Qué funcionó, qué no", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.mFootnote)
                        if let url = URL(string: "x-apple-health://") {
                            Link(destination: url) { Label("Abrir Salud", systemImage: "heart.fill") }
                        }
                    }
                }
            }
            .navigationTitle("Review semanal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }.disabled(!canSave)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    /// El último valor conocido como marcador: casi nunca cambia mucho de una semana a otra.
    private func placeholder(_ measure: BodyMeasure) -> String {
        viewModel.latest(measure).map { Goal.trim($0.value) } ?? measure.unitLabel
    }

    private func scale(_ title: String, value: Binding<Int>,
                       label: @escaping (Int) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.mSubheadline)
                Spacer()
                Text(label(value.wrappedValue)).font(.mCaption).foregroundStyle(Neon.accent)
            }
            Picker(title, selection: value) {
                ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func prefill() {
        // Solo el último review rellena las escalas; las medidas se dejan vacías a propósito
        // para que no se guarde sin querer el valor de la semana pasada.
        guard let last = viewModel.bodyLogs.first else { return }
        energy = last.energy
        hunger = last.hunger
    }

    private func save() async {
        let ok = await viewModel.saveReview(
            weight: parsed(weightText, as: .weight),
            waist: parsed(waistText, as: .waist),
            energy: energy,
            hunger: hunger,
            notes: notes,
            date: date
        )
        if ok { dismiss() }
    }
}
