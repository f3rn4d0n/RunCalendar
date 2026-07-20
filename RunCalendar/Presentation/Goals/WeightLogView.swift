import SwiftUI

/// Seguimiento corporal: peso, cintura y el review semanal.
/// Las medidas salen de **Salud** — lo que guardas aquí aparece en la app Salud y mueve la meta.
struct WeightLogView: View {
    @State var viewModel: GoalsViewModel

    @State private var logging: BodyMeasure?
    @State private var showReview = false

    private var goal: Goal? { viewModel.weightGoal }

    var body: some View {
        List {
            Section {
                ForEach(BodyMeasure.allCases) { measure in
                    LabeledContent(measure.displayName) {
                        if let latest = viewModel.latest(measure) {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(Goal.trim(latest.value)) \(measure.unitLabel)")
                                    .font(.mHeadline).foregroundStyle(Neon.accent)
                                Text(latest.date.mediumString())
                                    .font(.mCaption2).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Sin registros").foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Registrar") { logging = measure }.tint(Neon.accent)
                    }
                }

                Button { showReview = true } label: {
                    Label("Hacer review semanal", systemImage: "square.and.pencil")
                }
                .buttonStyle(NeonButtonStyle())
                .listRowBackground(Color.clear)
                .disabled(!viewModel.canLogMeasures)
            } header: {
                Text("Tus medidas")
            } footer: {
                Text(viewModel.canLogMeasures
                     ? "Se guardan en Apple Salud, así que también las verás en la app Salud. "
                       + "Desliza una medida para registrarla suelta."
                     : "Registrar medidas requiere Apple Salud (solo iPhone).")
            }

            // El aviso de recomposición vale más que la barra: explica una báscula quieta.
            if let trend = viewModel.recomposition {
                Section("Lo que la báscula no ve") {
                    Label {
                        Text("Tu peso casi no cambió, pero tu cintura bajó "
                             + "\(String(format: "%.1f", abs(trend.waistDeltaCm))) cm. "
                             + "Estás perdiendo grasa y ganando músculo.")
                            .font(.mSubheadline)
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(Neon.green)
                    }
                }
            }

            if let goal {
                Section("Meta de peso") {
                    let progress = viewModel.progress(for: goal)
                    LabeledContent("Objetivo", value: Goal.format(goal.targetValue, type: .weight))
                    if let start = goal.startValue {
                        LabeledContent("Punto de partida", value: Goal.format(start, type: .weight))
                    }
                    LabeledContent("Vas", value: progress.deltaText)
                    if let fraction = progress.fraction {
                        ProgressView(value: fraction).tint(Neon.green)
                    }
                }
            }

            if !viewModel.bodyLogs.isEmpty {
                Section("Reviews") {
                    ForEach(viewModel.bodyLogs) { log in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(log.date.mediumString()).font(.mSubheadline)
                            Text("Energía: \(BodyLog.energyLabel(log.energy)) · "
                                 + "Hambre: \(BodyLog.hungerLabel(log.hunger))")
                                .font(.mCaption).foregroundStyle(.secondary)
                            if !log.notes.isEmpty {
                                Text(log.notes).font(.mCaption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            ForEach(BodyMeasure.allCases) { measure in
                let entries = viewModel.history(for: measure)
                if !entries.isEmpty {
                    Section("Historial · \(measure.displayName)") {
                        ForEach(entries.prefix(20)) { entry in
                            HStack {
                                Text(entry.date.mediumString()).font(.mSubheadline)
                                Spacer()
                                Text("\(Goal.trim(entry.value)) \(measure.unitLabel)")
                                    .font(.mHeadline).foregroundStyle(Neon.accent)
                                if let delta = change(before: entry, in: entries) {
                                    Text(delta.text).font(.mCaption2).foregroundStyle(delta.color)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Cuerpo")
        .background(Neon.background)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.refreshBody() }
        .task { await viewModel.refreshBody() }
        .sheet(item: $logging) { MeasureEntrySheet(viewModel: viewModel, measure: $0) }
        .sheet(isPresented: $showReview) { WeeklyReviewView(viewModel: viewModel) }
    }

    /// Diferencia contra el registro anterior (la lista viene de más nuevo a más viejo).
    /// Bajar es bueno tanto en peso (si la meta es bajar) como en cintura.
    private func change(before entry: MeasurementEntry,
                        in entries: [MeasurementEntry]) -> (text: String, color: Color)? {
        guard let index = entries.firstIndex(of: entry), index + 1 < entries.count else { return nil }
        let diff = entry.value - entries[index + 1].value
        guard abs(diff) >= 0.05 else { return ("=", .secondary) }
        let sign = diff > 0 ? "+" : "−"
        let good = diff < 0
        return ("\(sign)\(String(format: "%.1f", abs(diff)))", good ? Neon.green : Neon.orange)
    }
}

/// Hoja para capturar una medida suelta (valor + fecha).
struct MeasureEntrySheet: View {
    @State var viewModel: GoalsViewModel
    let measure: BodyMeasure

    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var date = Date()

    private var parsed: Double? {
        // Rango sano: evita guardar en Salud un dedazo (7 kg, 700 kg).
        let value = Double(text.replacingOccurrences(of: ",", with: "."))
        return value.flatMap { measure.isValid($0) ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(measure.displayName) {
                    TextField(measure.unitLabel, text: $text)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $date, in: ...Date(), displayedComponents: .date)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.mFootnote)
                        // No hay deep link a la pantalla de permisos de la app dentro de Salud
                        // (no es API pública), así que abrimos Salud y el texto lleva el resto.
                        if let url = URL(string: "x-apple-health://") {
                            Link(destination: url) { Label("Abrir Salud", systemImage: "heart.fill") }
                        }
                    }
                }
            }
            .navigationTitle("Registrar \(measure.displayName.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            if await viewModel.logMeasure(measure, value: parsed ?? 0, date: date) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(parsed == nil)
                }
            }
            .onAppear {
                if text.isEmpty, let last = viewModel.latest(measure) { text = Goal.trim(last.value) }
            }
        }
    }
}
