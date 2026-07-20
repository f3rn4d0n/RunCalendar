import SwiftUI

/// Registro de peso: el valor de hoy, el progreso hacia la meta y el historial.
/// La fuente es **Salud** — lo que guardas aquí aparece en la app Salud y mueve la meta.
struct WeightLogView: View {
    @State var viewModel: GoalsViewModel

    @State private var showLogSheet = false

    private var goal: Goal? { viewModel.weightGoal }

    var body: some View {
        List {
            Section {
                if let latest = viewModel.latestWeight {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Goal.trim(latest.kg)) kg").font(.marker(38)).foregroundStyle(Neon.accent)
                        Text("Último registro · \(latest.date.mediumString())")
                            .font(.mCaption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("Aún no hay registros de peso en Salud.")
                        .font(.mSubheadline).foregroundStyle(.secondary)
                }

                Button {
                    showLogSheet = true
                } label: {
                    Label("Registrar peso de hoy", systemImage: "scalemass")
                }
                .buttonStyle(NeonButtonStyle())
                .listRowBackground(Color.clear)
                .disabled(!viewModel.canLogWeight)
            } header: {
                Text("Tu peso")
            } footer: {
                Text(viewModel.canLogWeight
                     ? "Se guarda en Apple Salud, así que también lo verás en la app Salud."
                     : "Registrar peso requiere Apple Salud (solo iPhone).")
            }

            if let goal {
                Section("Meta") {
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

            if !viewModel.weightHistory.isEmpty {
                Section("Historial") {
                    ForEach(viewModel.weightHistory) { entry in
                        HStack {
                            Text(entry.date.mediumString()).font(.mSubheadline)
                            Spacer()
                            Text("\(Goal.trim(entry.kg)) kg")
                                .font(.mHeadline).foregroundStyle(Neon.accent)
                            // Cambio contra el registro anterior, para leer la tendencia de un vistazo.
                            if let delta = change(before: entry) {
                                Text(delta.text).font(.mCaption2).foregroundStyle(delta.color)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Peso")
        .background(Neon.background)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.refreshWeight() }
        .task { await viewModel.refreshWeight() }
        .sheet(isPresented: $showLogSheet) {
            WeightEntrySheet(viewModel: viewModel)
        }
    }

    /// Diferencia contra el registro inmediatamente anterior (la lista viene de más nuevo a más viejo).
    private func change(before entry: WeightEntry) -> (text: String, color: Color)? {
        let history = viewModel.weightHistory
        guard let index = history.firstIndex(of: entry), index + 1 < history.count else { return nil }
        let diff = entry.kg - history[index + 1].kg
        guard abs(diff) >= 0.05 else { return ("=", .secondary) }
        let sign = diff > 0 ? "+" : "−"
        // Baja = verde solo si la meta es bajar; si no hay meta, se queda neutro.
        let losing = (viewModel.weightGoal?.startValue ?? .infinity) > (viewModel.weightGoal?.targetValue ?? 0)
        let good = losing ? diff < 0 : diff > 0
        return ("\(sign)\(String(format: "%.1f", abs(diff)))", good ? Neon.green : Neon.orange)
    }
}

/// Hoja para capturar un peso (valor + fecha). Precarga el último peso conocido.
struct WeightEntrySheet: View {
    @State var viewModel: GoalsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var date = Date()

    private var parsed: Double? {
        let value = Double(text.replacingOccurrences(of: ",", with: "."))
        // Rango sano: evita guardar en Salud un dedazo (7 kg, 700 kg).
        return value.flatMap { (20...400).contains($0) ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Peso") {
                    TextField("kg (p. ej. 78.4)", text: $text)
                        .keyboardType(.decimalPad)
                    DatePicker("Fecha", selection: $date, in: ...Date(), displayedComponents: .date)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.mFootnote)
                        // No hay deep link a la pantalla de permisos de la app dentro de Salud
                        // (no es API pública), así que abrimos Salud y el texto lleva el resto.
                        if let url = URL(string: "x-apple-health://") {
                            Link(destination: url) {
                                Label("Abrir Salud", systemImage: "heart.fill")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Registrar peso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { if await viewModel.logWeight(kg: parsed ?? 0, date: date) { dismiss() } }
                    }
                    .disabled(parsed == nil)
                }
            }
            .onAppear {
                if text.isEmpty, let last = viewModel.latestWeight { text = Goal.trim(last.kg) }
            }
        }
    }
}
