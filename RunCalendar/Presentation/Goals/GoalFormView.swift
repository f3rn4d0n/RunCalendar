import SwiftUI

/// Alta/edición de un objetivo. Los campos cambian según el tipo (tiempo, VO₂max, peso,
/// volumen semanal, FC en reposo, tirada larga).
struct GoalFormView: View {
    @State var viewModel: GoalsViewModel
    let goal: Goal?

    @Environment(\.dismiss) private var dismiss

    @State private var type: GoalType = .raceTime
    @State private var distance: RaceDiscipline = .fiveK
    @State private var timeText = ""       // mm:ss
    @State private var valueText = ""      // cualquier meta numérica (kg, km, lpm, VO₂max)
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var notes = ""
    @State private var suggestion: String?
    @State private var startText = ""      // punto de partida (base de la barra de progreso)

    /// Punto de partida parseado; `nil` = dejarlo como estaba.
    private var parsedStart: Double? {
        switch type {
        case .raceTime: return Goal.parseTime(startText).map(Double.init)
        default:        return Double(startText.replacingOccurrences(of: ",", with: "."))
        }
    }

    /// Distancias con tiempo objetivo (las estándar).
    private static let distances: [RaceDiscipline] = [.fiveK, .tenK, .fifteenK, .halfMarathon, .marathon]

    private var isNew: Bool { goal == nil }

    /// Valor objetivo parseado según el tipo (nil = inválido).
    private var parsedTarget: Double? {
        switch type {
        case .raceTime: return Goal.parseTime(timeText).map(Double.init)
        default:        return Double(valueText.replacingOccurrences(of: ",", with: "."))
        }
    }

    /// Ritmo semanal esperado — reactivo a la meta y la fecha (se recalcula al editarlas).
    private var pace: GoalPace? {
        guard let target = parsedTarget, hasDeadline else { return nil }
        return viewModel.expectedPace(type: type, distance: type == .raceTime ? distance : nil,
                                      target: target, deadline: deadline)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Objetivo", selection: $type) {
                        ForEach(GoalType.allCases) {
                            Label($0.displayName, systemImage: $0.systemImage).tag($0)
                        }
                    }
                }

                Section {
                    switch type {
                    case .raceTime:
                        Picker("Distancia", selection: $distance) {
                            ForEach(Self.distances) { Text($0.displayName).tag($0) }
                        }
                        TextField(type.inputHint, text: $timeText)
                    default:
                        TextField(type.inputHint, text: $valueText)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Meta")
                } footer: {
                    if type.isAutoMeasured {
                        Text("Se mide sola: la app la lee de tus entrenamientos y de Salud, "
                            + "no tienes que registrar nada a mano.")
                    }
                }

                Section {
                    switch type {
                    case .raceTime:
                        TextField("Tiempo de partida (p. ej. 30:00)", text: $startText)
                    default:
                        TextField("Valor de partida", text: $startText)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Punto de partida")
                } footer: {
                    Text("Desde dónde arrancaste. Es la base de la barra de progreso; "
                        + "se toma de tus datos al crear la meta, pero puedes corregirlo.")
                }

                Section {
                    Toggle("Fecha límite", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Para", selection: $deadline, displayedComponents: .date)
                    }
                }

                Section {
                    Button(action: suggest) {
                        Label("Sugerir meta y fecha", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(NeonButtonStyle())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text(suggestion
                        ?? "Te proponemos una meta y una fecha realistas con tus datos (PRs, Salud y tus entrenamientos).")
                }

                if let pace {
                    Section("Progreso esperado") {
                        Label(pace.weekly, systemImage: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(Neon.accent)
                        Text(pace.summary).font(.mCaption).foregroundStyle(.secondary)
                    }
                }

                Section("Notas") {
                    TextField("Notas", text: $notes, axis: .vertical).lineLimit(2...4)
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.mFootnote) }
                }
            }
            .navigationTitle(isNew ? "Nuevo objetivo" : "Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }.disabled(parsedTarget == nil)
                }
            }
            .onAppear { populate() }
        }
    }

    private func populate() {
        guard let goal else { return }
        type = goal.type
        distance = goal.distance ?? .fiveK
        switch goal.type {
        case .raceTime: timeText = Goal.formatTime(Int(goal.targetValue))
        default:        valueText = Goal.trim(goal.targetValue)
        }
        if let start = goal.startValue {
            startText = goal.type == .raceTime ? Goal.formatTime(Int(start)) : Goal.trim(start)
        }
        hasDeadline = goal.deadline != nil
        deadline = goal.deadline ?? Date()
        notes = goal.notes
    }

    /// Rellena la meta con la recomendación (editable) y muestra el porqué.
    private func suggest() {
        guard let rec = viewModel.recommendation(type: type, distance: type == .raceTime ? distance : nil) else {
            suggestion = "Aún no hay datos para sugerir. Registra carreras o tus datos en Salud."
            return
        }
        switch type {
        case .raceTime: timeText = Goal.formatTime(Int(rec.targetValue))
        default:        valueText = Goal.trim(rec.targetValue)
        }
        if let date = rec.deadline {
            hasDeadline = true
            deadline = date
        }
        suggestion = rec.rationale
    }

    private func save() async {
        guard let target = parsedTarget else { return }
        let newGoal = Goal(
            id: goal?.id ?? UUID().uuidString,
            type: type,
            targetValue: target,
            startValue: parsedStart ?? goal?.startValue,
            distance: type == .raceTime ? distance : nil,
            deadline: hasDeadline ? deadline : nil,
            notes: notes,
            createdAt: goal?.createdAt ?? Date()
        )
        if await viewModel.save(newGoal, isNew: isNew) { dismiss() }
    }
}
