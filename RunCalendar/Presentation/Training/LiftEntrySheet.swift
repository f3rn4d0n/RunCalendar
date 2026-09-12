import SwiftUI

/// Alta o edición de un resultado puntual de levantamiento. En alta (`effort == nil`) el ejercicio
/// ya viene fijado por quién abrió la hoja y se captura la fecha; al editar, la fecha es de la
/// sesión dueña si el esfuerzo vino de un WOD (o del propio registro suelto) y no tiene sentido
/// tocarla aquí —solo peso y repeticiones.
struct LiftEntrySheet: View {
    let weightliftingViewModel: WeightliftingViewModel
    let exercise: StrengthExercise
    /// `nil` = alta de un registro nuevo. Con valor = edición de ese esfuerzo puntual.
    let effort: LiftEffort?

    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var showDeleteAlert = false

    private var isNew: Bool { effort == nil }
    private var weight: Double? { Double(weightText.replacingOccurrences(of: ",", with: ".")) }
    private var reps: Int? { Int(repsText) }
    private var canSave: Bool { (weight ?? -1) >= 0 && (reps ?? 0) > 0 }

    private var weightLabel: String {
        exercise.loadStyle == .external ? "Peso (kg)" : "Lastre (kg)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(exercise.displayName) {
                    if isNew {
                        DatePicker("Fecha", selection: $date, in: ...Date(), displayedComponents: .date)
                    }
                    LabeledContent(weightLabel) {
                        TextField("kg", text: $weightText)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Repeticiones") {
                        TextField("reps", text: $repsText)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                }

                if let error = weightliftingViewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.mFootnote) }
                }

                // Solo se puede borrar un registro suelto: una serie de WOD se edita desde la
                // sesión completa, no desde aquí.
                if let effort, case .entry = effort.origin {
                    Section {
                        Button(role: .destructive) { showDeleteAlert = true } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Nuevo resultado" : "Editar resultado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }.disabled(!canSave)
                }
            }
            .onAppear(perform: populate)
            .alert("¿Eliminar este resultado?", isPresented: $showDeleteAlert) {
                Button("Eliminar", role: .destructive) { Task { await deleteLooseEntry() } }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    private func populate() {
        guard let effort else { return }
        date = effort.date
        weightText = Goal.trim(effort.weightKg)
        repsText = "\(effort.reps)"
    }

    private func save() async {
        guard let weight, let reps else { return }
        let ok: Bool
        if let effort {
            ok = await weightliftingViewModel.updatePerformance(of: effort, weightKg: weight, reps: reps)
        } else {
            ok = await weightliftingViewModel.save(
                LiftEntry(exercise: exercise, weightKg: weight, reps: reps, date: date), isNew: true)
        }
        if ok { dismiss() }
    }

    private func deleteLooseEntry() async {
        guard case .entry(let entryID) = effort?.origin,
              let entry = weightliftingViewModel.entries.first(where: { $0.id == entryID })
        else { return }
        await weightliftingViewModel.delete(entry)
        dismiss()
    }
}
